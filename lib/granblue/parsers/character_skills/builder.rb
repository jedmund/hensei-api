# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Builds the normalized skill graph (slots → versions → links) from a
      # character's wiki/game data. Assembles slots/versions and wires variant
      # links; classification heuristics are delegated to InferenceRules, effects
      # to the injected EffectParser, and field text to FieldParser.
      class Builder
        TYPE_COLORS = {
          'red' => 'damage',
          'green' => 'heal',
          'yellow' => 'buff',
          'blue' => 'debuff',
          'purple' => 'field'
        }.freeze

        # Game ability icon stem "{id}_{N}" (N = border color); the asset lives at
        # .../ui/icon/ability/m/{stem}.png. gbf.wiki stores the same stem as
        # "Ability_m_{id}_{N}.png", used as a fallback when game data lacks it.
        ICON_STEM = /\A\d+_\d+\z/
        WIKI_ICON_STEM = /\AAbility_m_(\d+_\d+)\.png\z/i

        attr_reader :effect_parser

        def initialize(character, data:, effect_parser:)
          @character = character
          @data = data
          @effect_parser = effect_parser
          @links = []
          @version_keys = Set.new
        end

        def build
          slots = build_ability_slots + build_ougi_slots + build_support_slots
          { character_granblue_id: character.granblue_id, slots: slots, links: filtered_links }
        end

        private

        attr_reader :character, :data

        def wiki_params
          data.params
        end

        # Links whose endpoints both exist as built versions (drops dangling links).
        def filtered_links
          @links.select do |link|
            @version_keys.include?(link[:from_version_key]) && @version_keys.include?(link[:to_version_key])
          end
        end

        def build_ability_slots
          count = wiki_params['abilitycount'].to_i
          return [] if count.zero?

          slots = (1..count).filter_map { |position| build_ability_slot(position) }
          resolve_variants(slots)
          slots
        end

        def build_ability_slot(position)
          base_key = "a#{position}"
          return if wiki_params["#{base_key}_name"].blank?

          game = data.game_action(base_key)
          slot = {
            key: slot_key('ability', position),
            attrs: {
              character_granblue_id: character.granblue_id,
              kind: 'ability',
              position: position,
              game_action_id: game&.dig('action_id')
            },
            versions: []
          }

          role = InferenceRules.base_role(wiki_params["#{base_key}_effdesc"], wiki_params["#{base_key}_option"])
          base_version = build_version(base_key, slot, role: role, ordinal: next_ordinal(slot), overrides: inline_base_overrides(base_key))
          slot[:versions] << base_version

          build_enhanced_versions(base_key, slot, base_version).each { |version| slot[:versions] << version }
          build_inline_transform_alt(base_key, slot, base_version)&.then { |version| slot[:versions] << version }

          slot
        end

        def build_ougi_slots
          ougi_keys = wiki_params.keys.grep(/\Aougi\d*_name\z/).sort_by { |key| key[/\d+/].to_i }
          ougi_keys = ['ougi_name'] if ougi_keys.empty? && wiki_params['ougi_name'].present?
          return [] if ougi_keys.none? { |key| wiki_params[key].present? }

          slot = {
            key: slot_key('ougi', 1),
            attrs: {
              character_granblue_id: character.granblue_id,
              kind: 'ougi',
              position: 1,
              game_action_id: data.game_action('ougi')&.dig('action_id')
            },
            versions: []
          }

          ougi_keys.each do |name_key|
            next if wiki_params[name_key].blank?

            key = name_key.delete_suffix('_name')
            role, min_uncap, transcendence_stage = InferenceRules.ougi_progression(key, wiki_params["#{key}_label"])
            slot[:versions] << build_version(
              key, slot, role: role, ordinal: next_ordinal(slot),
              overrides: { min_uncap: min_uncap, transcendence_stage: transcendence_stage }
            )
          end

          [slot]
        end

        def build_support_slots
          count = wiki_params['s_abilitycount'].to_i
          return [] if count.zero?

          (1..count).filter_map do |position|
            key = position == 1 ? 'sa' : "sa#{position}"
            next if wiki_params["#{key}_name"].blank?

            slot = {
              key: slot_key('support', position),
              attrs: { character_granblue_id: character.granblue_id, kind: 'support', position: position, game_action_id: nil },
              versions: []
            }

            base_version = build_version(key, slot, role: 'base', ordinal: next_ordinal(slot))
            slot[:versions] << base_version
            build_enhanced_versions(key, slot, base_version, description_suffix: 'desc').each { |version| slot[:versions] << version }
            slot
          end
        end

        def resolve_variants(slots)
          variant_groups.each do |group|
            (1..group[:count]).each do |index|
              parent_position = group[:parent_position] || (group[:role] == 'form_alt' ? index : nil)
              parent = slots.find { |slot| slot[:attrs][:kind] == 'ability' && slot[:attrs][:position] == parent_position }
              next unless parent

              parent_version = option_parent_version(parent)
              key = "a#{index}#{group[:suffix]}"
              next if wiki_params["#{key}_name"].blank?

              version = build_version(key, parent, role: group[:role], ordinal: next_ordinal(parent), overrides: trigger_for_group(group, parent))
              parent[:versions] << version

              relation = InferenceRules.relation_for_role(group[:role])
              add_link(parent_version[:key], version[:key], relation) if relation
            end
          end
        end

        def variant_groups
          groups = wiki_params.keys.grep(/\Aability(?:title|subtitle)_[a-z]\z/).filter_map do |key|
            suffix = key[-1]
            title = wiki_params["abilitytitle_#{suffix}"].to_s
            subtitle = wiki_params["abilitysubtitle_#{suffix}"].to_s
            parent_position = title[/CharacterSkill[2]?\|.*?\|(\d+)/, 1]&.to_i
            count = wiki_params["abilitycount_#{suffix}"].to_i
            next if count.zero?
            next if parent_position.blank? && subtitle.blank?

            { suffix: suffix, parent_position: parent_position, count: count, role: InferenceRules.group_role(title, subtitle), title: title,
subtitle: subtitle }
          end

          groups.uniq { |group| group[:suffix] }
        end

        def build_inline_transform_alt(base_key, slot, base_version)
          return unless inline_alt?(base_key)

          names = FieldParser.split_name(wiki_params["#{base_key}_name"])
          return if names.second.blank?

          version = build_version(
            base_key, slot, role: 'transform_alt', ordinal: next_ordinal(slot),
            overrides: {
              name_en: names.second,
              trigger_type: InferenceRules.trigger_type_for_text(wiki_params["#{base_key}_effdesc"]),
              trigger_value: InferenceRules.trigger_value_for_text(wiki_params["#{base_key}_effdesc"])
            }
          )
          add_link(base_version[:key], version[:key], 'transforms_to')
          version
        end

        def inline_base_overrides(base_key)
          return {} unless inline_alt?(base_key)

          first_name = FieldParser.split_name(wiki_params["#{base_key}_name"]).first
          first_name.present? ? { name_en: first_name } : {}
        end

        def inline_alt?(base_key)
          wiki_params["#{base_key}_option"].to_s.include?('alt') ||
            wiki_params["#{base_key}_option1"].to_s.include?('alt')
        end

        def build_enhanced_versions(base_key, slot, base_version, description_suffix: 'effdesc')
          levels = FieldParser.parse_ob_levels(wiki_params["#{base_key}_oblevel"] || wiki_params["#{base_key}_level"])[:enhanced]
          info_desc = FieldParser.parse_info_des(wiki_params["#{base_key}_#{description_suffix}"])
          cooldowns = FieldParser.parse_cooldown(wiki_params["#{base_key}_cd"])

          levels.each_with_index.filter_map do |level, index|
            description = info_desc[:descriptions][index + 1]
            cooldown = cooldowns[:enhanced][index]
            next if description.blank? && cooldown.blank?

            build_version(
              base_key, slot, role: InferenceRules.enhanced_role(level), ordinal: next_ordinal(slot),
              overrides: {
                **inline_base_overrides(base_key),
                unlock_level: level,
                enhance_levels: [level],
                transcendence_stage: InferenceRules.transcendence_stage(level),
                description_en: description.presence || base_version[:attrs][:description_en],
                cooldown: cooldown.presence || base_version[:attrs][:cooldown]
              }
            )
          end
        end

        def build_version(key, slot, role:, ordinal:, overrides: {})
          raw_description_en = FieldParser.clean_description(overrides[:description_en] || description_for(key))
          version_key = version_key(slot, key, role, ordinal)
          @version_keys << version_key

          {
            key: version_key,
            source_key: key,
            attrs: version_attrs(key, role: role, ordinal: ordinal, raw_description_en: raw_description_en, overrides: overrides).compact,
            effects: effect_parser.parse(raw_description_en)
          }
        end

        def version_attrs(key, role:, ordinal:, raw_description_en:, overrides:)
          game = data.game_action(key)
          jp = data.game_action(key, lang: :jp)
          description = description_for(key)
          ob_levels = FieldParser.parse_ob_levels(wiki_params["#{key}_oblevel"] || wiki_params["#{key}_level"])
          cooldown = FieldParser.parse_cooldown(wiki_params["#{key}_cd"])
          duration = FieldParser.parse_duration_value(wiki_params["#{key}_dur"])
          {
            name_en: FieldParser.clean_markup(overrides[:name_en] || wiki_params["#{key}_name"] || game&.dig('name_en') || game&.dig('name')),
            name_jp: FieldParser.jp_name_for(jp),
            description_en: FieldParser.display_description(raw_description_en),
            description_jp: FieldParser.display_description(FieldParser.clean_description(jp&.dig('comment'))),
            icon: FieldParser.first_icon(wiki_params["#{key}_icon"]),
            game_icon: game_icon_for(key, game),
            type_color: TYPE_COLORS[wiki_params["#{key}_color"].to_s.strip.downcase],
            cooldown: cooldown[:base],
            initial_cooldown: cooldown[:initial],
            duration_value: duration[:value],
            duration_unit: duration[:unit],
            variant_role: role,
            ordinal: ordinal,
            unlock_level: ob_levels[:obtained],
            enhance_levels: ob_levels[:enhanced],
            min_uncap: 4,
            transcendence_stage: nil,
            trigger_type: 'none',
            trigger_value: nil,
            cant_recast: InferenceRules.cant_recast?(description),
            one_time_use: InferenceRules.one_time_use?(description),
            auto_activate: InferenceRules.auto_activate?(description),
            mimicable: wiki_params["#{key}_mimic"].to_s.strip == 'y',
            targets_all: InferenceRules.targets_all?(description),
            game_action_id: game&.dig('action_id')
          }.merge(overrides.except(:name_en, :description_en))
        end

        # The game asset stem for this version's icon. Prefers game-data
        # class_name ("625_4"); falls back to a wiki icon already in stem form.
        def game_icon_for(key, game)
          class_name = game&.dig('class_name').to_s.strip
          return class_name if class_name.match?(ICON_STEM)

          FieldParser.first_icon(wiki_params["#{key}_icon"]).to_s[WIKI_ICON_STEM, 1]
        end

        def description_for(key)
          parsed = FieldParser.parse_info_des(wiki_params["#{key}_effdesc"] || wiki_params["#{key}_desc"])
          parsed[:descriptions].first.presence || wiki_params["#{key}_desc"]
        end

        def trigger_for_group(group, parent)
          case group[:role]
          when 'option'
            { trigger_type: 'menu_select' }
          when 'form_alt'
            { trigger_type: 'form_state', trigger_value: FieldParser.clean_trigger_value(group[:subtitle].presence || group[:title]) }
          else
            parent_text = parent[:versions].first&.dig(:attrs, :description_en)
            { trigger_type: InferenceRules.trigger_type_for_text(parent_text), trigger_value: InferenceRules.trigger_value_for_text(parent_text) }
          end
        end

        def option_parent_version(slot)
          slot[:versions].reverse.find { |version| version[:attrs][:variant_role] == 'transform_alt' } || slot[:versions].first
        end

        def add_link(from_key, to_key, relation)
          @links << { from_version_key: from_key, to_version_key: to_key, relation: relation }
        end

        def next_ordinal(slot)
          slot[:versions].size + 1
        end

        def slot_key(kind, position)
          "#{kind}:#{position}"
        end

        def version_key(slot, key, role, ordinal)
          "#{slot[:key]}:#{key}:#{role}:#{ordinal}"
        end
      end
    end
  end
end
