# frozen_string_literal: true

module Granblue
  module Parsers
    # Parses character ability/ougi/support wiki params into the normalized graph.
    class CharacterSkillParser
      # A skill relearned at or past this level is a Transcendence upgrade.
      TRANSCENDENCE_MIN_LEVEL = 120
      # Level threshold => Transcendence stage (checked high to low).
      TRANSCENDENCE_STAGE_LEVELS = { 150 => 5, TRANSCENDENCE_MIN_LEVEL => 1 }.freeze

      # Variant roles whose JP text comes from a transform row, not the base skill.
      STATE_VARIANT_ROLES = %w[transform_alt form_alt option].freeze

      TYPE_COLORS = {
        'red' => 'damage',
        'green' => 'heal',
        'yellow' => 'buff',
        'blue' => 'debuff',
        'purple' => 'field'
      }.freeze

      attr_reader :character

      # status_lookup: an optional preloaded { by_name:, by_id: } index so a batch
      # run resolves the Status catalog once instead of per character.
      def initialize(character, status_lookup: nil)
        @character = character
        @data = CharacterWikiData.new(character)
        @status_lookup = status_lookup
        @missing_fields = []
        @links = []
        @version_keys = Set.new
      end

      def parse(persist: false)
        graph = {
          character_granblue_id: character.granblue_id,
          slots: build_ability_slots + build_ougi_slots + build_support_slots,
          links: []
        }

        apply_jp_localization(graph[:slots])

        graph[:links] = @links.select do |link|
          @version_keys.include?(link[:from_version_key]) && @version_keys.include?(link[:to_version_key])
        end

        report = report_for(graph)
        persist_graph!(graph) if persist
        report
      end

      def self.persist_all(debug: false, overwrite: false)
        characters = Character.where.not(wiki_raw: [nil, ''])
        characters = characters.left_joins(:character_skills).where(character_skills: { id: nil }) unless overwrite

        total = characters.count
        processed = 0
        errors = []
        status_lookup = build_status_lookup

        characters.find_each.with_index do |character, index|
          if debug
            percentage = total.zero? ? 100.0 : ((index + 1) / total.to_f * 100).round(1)
            puts "#{percentage}%: Processing skills for #{character.name_en} (#{character.granblue_id})..."
          end

          new(character, status_lookup: status_lookup).parse(persist: true)
          processed += 1
        rescue StandardError => e
          errors << "#{character.granblue_id}: #{e.message}"
          Rails.logger.error "[CHARACTER_SKILLS] Failed for #{character.granblue_id}: #{e.message}"
        end

        { processed: processed, skipped: total - processed - errors.size, errors: errors }
      end

      # Preloads the Status catalog into name/id indexes for O(1) lookups.
      def self.build_status_lookup
        Status.all.each_with_object({ by_name: {}, by_id: {} }) do |status, acc|
          acc[:by_name][status.name_en.to_s.downcase] = status
          acc[:by_id][status.id] = status
        end
      end

      private

      attr_reader :data

      def wiki_params
        data.params
      end

      def status_lookup
        @status_lookup ||= self.class.build_status_lookup
      end

      def effect_parser
        @effect_parser ||= CharacterSkills::EffectParser.new(status_lookup)
      end

      def build_ability_slots
        count = wiki_params['abilitycount'].to_i
        return [] if count.zero?

        slots = (1..count).filter_map do |position|
          build_ability_slot(position)
        end

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

        base_overrides = inline_base_overrides(base_key)
        base_version = build_version(base_key, slot, role: base_role_for(base_key), ordinal: next_ordinal(slot), overrides: base_overrides)
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
          role, min_uncap, transcendence_stage = ougi_progression_for(key)
          slot[:versions] << build_version(
            key,
            slot,
            role: role,
            ordinal: next_ordinal(slot),
            overrides: {
              min_uncap: min_uncap,
              transcendence_stage: transcendence_stage
            }
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
            attrs: {
              character_granblue_id: character.granblue_id,
              kind: 'support',
              position: position,
              game_action_id: nil
            },
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

            role = group[:role]
            version = build_version(
              key,
              parent,
              role: role,
              ordinal: next_ordinal(parent),
              overrides: trigger_for_group(group, parent)
            )
            parent[:versions] << version

            relation = relation_for_role(role)
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

          {
            suffix: suffix,
            parent_position: parent_position,
            count: count,
            role: group_role(title, subtitle),
            title: title,
            subtitle: subtitle
          }
        end

        groups.uniq { |group| group[:suffix] }
      end

      # A group's own subtitle marks a form set; otherwise the title flags an
      # options menu, and everything else is a transform/alt set.
      def group_role(title, subtitle)
        if subtitle.present?
          'form_alt'
        elsif title.include?('Character/Skills/Options')
          'option'
        else
          'transform_alt'
        end
      end

      def build_inline_transform_alt(base_key, slot, base_version)
        return unless inline_alt?(base_key)

        names = split_name(wiki_params["#{base_key}_name"])
        return if names.second.blank?

        version = build_version(
          base_key,
          slot,
          role: 'transform_alt',
          ordinal: next_ordinal(slot),
          overrides: {
            name_en: names.second,
            trigger_type: trigger_type_for_text(wiki_params["#{base_key}_effdesc"]),
            trigger_value: trigger_value_for_text(wiki_params["#{base_key}_effdesc"])
          }
        )
        add_link(base_version[:key], version[:key], 'transforms_to')
        version
      end

      def inline_base_overrides(base_key)
        return {} unless inline_alt?(base_key)

        first_name = split_name(wiki_params["#{base_key}_name"]).first
        first_name.present? ? { name_en: first_name } : {}
      end

      def inline_alt?(base_key)
        wiki_params["#{base_key}_option"].to_s.include?('alt') ||
          wiki_params["#{base_key}_option1"].to_s.include?('alt')
      end

      def build_enhanced_versions(base_key, slot, base_version, description_suffix: 'effdesc')
        levels = parse_ob_levels(wiki_params["#{base_key}_oblevel"] || wiki_params["#{base_key}_level"])[:enhanced]
        info_desc = parse_info_des(wiki_params["#{base_key}_#{description_suffix}"])
        cooldowns = parse_cooldown(wiki_params["#{base_key}_cd"])

        levels.each_with_index.filter_map do |level, index|
          description = info_desc[:descriptions][index + 1]
          cooldown = cooldowns[:enhanced][index]
          next if description.blank? && cooldown.blank?

          role = level >= TRANSCENDENCE_MIN_LEVEL ? 'transcendence_upgrade' : 'enhanced'
          build_version(
            base_key,
            slot,
            role: role,
            ordinal: next_ordinal(slot),
            overrides: {
              **inline_base_overrides(base_key),
              unlock_level: level,
              enhance_levels: [level],
              transcendence_stage: transcendence_stage_for_level(level),
              description_en: description.presence || base_version[:attrs][:description_en],
              cooldown: cooldown.presence || base_version[:attrs][:cooldown]
            }
          )
        end
      end

      def build_version(key, slot, role:, ordinal:, overrides: {})
        description = description_for(key)
        game = data.game_action(key)
        jp = data.game_action(key, lang: :jp)
        ob_levels = parse_ob_levels(wiki_params["#{key}_oblevel"] || wiki_params["#{key}_level"])
        info_desc = parse_info_des(wiki_params["#{key}_effdesc"] || wiki_params["#{key}_desc"])
        cooldown = parse_cooldown(wiki_params["#{key}_cd"])
        duration = parse_duration_value(wiki_params["#{key}_dur"])
        raw_description_en = clean_description(overrides[:description_en] || description || info_desc[:descriptions].first)
        attrs = {
          name_en: clean_markup(overrides[:name_en] || wiki_params["#{key}_name"] || game&.dig('name_en') || game&.dig('name')),
          name_jp: jp_name_for(jp),
          description_en: display_description(raw_description_en),
          description_jp: display_description(clean_description(jp&.dig('comment'))),
          icon: first_icon(wiki_params["#{key}_icon"]),
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
          cant_recast: cant_recast?(description),
          one_time_use: one_time_use?(description),
          auto_activate: auto_activate?(description),
          mimicable: wiki_params["#{key}_mimic"].to_s.strip == 'y',
          targets_all: targets_all?(description),
          game_action_id: game&.dig('action_id')
        }.merge(overrides.except(:name_en, :description_en))

        version_key = version_key(slot, key, role, ordinal)
        @version_keys << version_key

        {
          key: version_key,
          source_key: key,
          attrs: attrs.compact,
          effects: effect_parser.parse(raw_description_en)
        }
      end

      def display_description(text)
        CharacterSkills::FieldParser.display_description(text)
      end

      # Fills name_jp/description_jp from the cached Japanese wiki (wiki_raw_jp),
      # aligned to the EN graph by slot position. No-op when JP HTML is absent.
      def apply_jp_localization(slots)
        return if character.wiki_raw_jp.blank?

        jp = Granblue::Parsers::JpWikiSkillParser.new(character).parse
        ability_groups = group_jp_abilities(jp[:abilities])

        slots.each do |slot|
          case slot[:attrs][:kind]
          when 'ability'
            localize_slot(slot, ability_groups[slot[:attrs][:position] - 1])
          when 'ougi'
            slot[:versions].each_with_index { |version, index| set_jp(version, jp[:ougi][index]) }
          when 'support'
            entry = jp[:support][slot[:attrs][:position] - 1]
            slot[:versions].each { |version| set_jp(version, entry) }
          end
        end
      end

      # JP abilities are a flat list where transform/option rows follow their
      # base. A cooldown-bearing row starts a new slot group; the rest attach.
      def group_jp_abilities(abilities)
        abilities.each_with_object([]) do |entry, groups|
          if groups.empty? || entry.key?(:cooldown)
            groups << [entry]
          else
            groups.last << entry
          end
        end
      end

      def localize_slot(slot, group)
        return if group.blank?

        base = group.first
        transforms = group.drop(1)
        slot[:versions].each do |version|
          alt = transforms.shift if STATE_VARIANT_ROLES.include?(version[:attrs][:variant_role])
          set_jp(version, alt || base)
        end
      end

      def set_jp(version, jp_entry)
        return if jp_entry.blank?

        version[:attrs][:name_jp] ||= jp_entry[:name_jp].presence
        version[:attrs][:description_jp] ||= jp_entry[:effect_jp].to_s.gsub(/\s+/, ' ').strip.presence
      end

      def cross_validate_statuses(graph)
        graph[:slots].flat_map do |slot|
          slot[:versions].filter_map do |version|
            game_ids = data.csv(data.game_action(version[:source_key])&.dig('ailment'))
            parsed_ids = version[:effects].filter_map { |effect| effect[:status_id] && status_ailment_id(effect[:status_id]) }
            missing = game_ids - parsed_ids
            next if missing.empty?

            {
              slot: slot[:attrs].slice(:kind, :position),
              version: version[:attrs][:name_en],
              missing_game_ailment_ids: missing
            }
          end
        end
      end

      def persist_graph!(graph)
        ActiveRecord::Base.transaction do
          CharacterSkill.where(character_granblue_id: character.granblue_id).destroy_all

          versions_by_key = {}
          graph[:slots].each do |slot_hash|
            slot = CharacterSkill.create!(permitted_attrs(CharacterSkill, slot_hash[:attrs]))
            slot_hash[:versions].each do |version_hash|
              version_attrs = permitted_attrs(CharacterSkillVersion, version_hash[:attrs]).merge(character_skill_id: slot.id)
              version = CharacterSkillVersion.create!(version_attrs)
              versions_by_key[version_hash[:key]] = version

              version_hash[:effects].each do |effect_hash|
                effect_attrs = permitted_attrs(SkillEffect, effect_hash).merge(character_skill_version_id: version.id)
                SkillEffect.create!(effect_attrs)
              end
            end
          end

          graph[:links].each do |link_hash|
            from_version = versions_by_key[link_hash[:from_version_key]]
            to_version = versions_by_key[link_hash[:to_version_key]]
            next if from_version.blank? || to_version.blank?

            CharacterSkillVersionLink.create!(
              from_version_id: from_version.id,
              to_version_id: to_version.id,
              relation: link_hash[:relation]
            )
          end
        end
      end

      def report_for(graph)
        {
          character_granblue_id: character.granblue_id,
          counts: {
            slots: graph[:slots].size,
            versions: graph[:slots].sum { |slot| slot[:versions].size },
            effects: graph[:slots].sum { |slot| slot[:versions].sum { |version| version[:effects].size } },
            links: graph[:links].size
          },
          unmatched_statuses: effect_parser.unmatched_statuses.to_a.sort,
          missing_fields: @missing_fields.uniq,
          cross_validation: cross_validate_statuses(graph),
          slots: graph[:slots],
          links: graph[:links]
        }
      end

      def permitted_attrs(model, attrs)
        attrs.slice(*model.column_names.map(&:to_sym))
      end

      def description_for(key)
        parsed = parse_info_des(wiki_params["#{key}_effdesc"] || wiki_params["#{key}_desc"])
        parsed[:descriptions].first.presence || wiki_params["#{key}_desc"]
      end

      def parse_info_des(value)
        CharacterSkills::FieldParser.parse_info_des(value)
      end

      def parse_cooldown(value)
        CharacterSkills::FieldParser.parse_cooldown(value)
      end

      def parse_duration_value(value)
        CharacterSkills::FieldParser.parse_duration_value(value)
      end

      def parse_ob_levels(value)
        CharacterSkills::FieldParser.parse_ob_levels(value)
      end

      def ougi_progression_for(key)
        return ['base', 4, nil] if key == 'ougi'

        label = wiki_params["#{key}_label"].to_s
        if (stage = label[/Stage (\d+) Transcendence/i, 1])
          ['transcendence_upgrade', 6, stage.to_i]
        elsif label.include?('uncap=5') || label.match?(/5★|After 5/i)
          ['uncap_upgrade', 5, nil]
        elsif label.match?(/Sword form/i)
          ['form_alt', 4, nil]
        else
          ['base', 4, nil]
        end
      end

      def base_role_for(key)
        text = wiki_params["#{key}_effdesc"].to_s
        return 'conditional' if text.match?(/effect changes based/i) && wiki_params["#{key}_option"].to_s.exclude?('options')

        'base'
      end

      def trigger_for_group(group, parent)
        case group[:role]
        when 'option'
          { trigger_type: 'menu_select' }
        when 'form_alt'
          { trigger_type: 'form_state', trigger_value: clean_trigger_value(group[:subtitle].presence || group[:title]) }
        else
          parent_text = parent[:versions].first&.dig(:attrs, :description_en)
          { trigger_type: trigger_type_for_text(parent_text), trigger_value: trigger_value_for_text(parent_text) }
        end
      end

      def trigger_type_for_text(text)
        normalized = trigger_text(text).downcase
        return 'stack_threshold' if normalized.match?(/when .* (?:is|reaches) \d|at \d/)
        return 'field_effect' if normalized.include?('utopia')
        return 'on_cast_toggle' if normalized.include?('changes to') || normalized.include?('upon casting')

        'contextual'
      end

      def trigger_value_for_text(text)
        plain_text = trigger_text(text)
        return 'Utopia active' if plain_text.match?(/Utopia/i)

        if (match = plain_text.match(/When ([^:<]+?) (?:is|reaches) (\d+)/i))
          return "#{match[1].strip} >= #{match[2]}"
        end

        nil
      end

      def trigger_text(text)
        clean_markup(text).gsub(/\{\{status\|([^|}]+).*?\}\}/i, '\\1')
      end

      def transcendence_stage_for_level(level)
        TRANSCENDENCE_STAGE_LEVELS.each { |threshold, stage| return stage if level >= threshold }

        nil
      end

      def option_parent_version(slot)
        slot[:versions].reverse.find { |version| version[:attrs][:variant_role] == 'transform_alt' } || slot[:versions].first
      end

      def relation_for_role(role)
        {
          'option' => 'option_of',
          'form_alt' => 'form_counterpart',
          'transform_alt' => 'transforms_to'
        }[role]
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

      def split_name(name)
        CharacterSkills::FieldParser.split_name(name)
      end

      def jp_name_for(game_action)
        CharacterSkills::FieldParser.jp_name_for(game_action)
      end

      def first_icon(value)
        CharacterSkills::FieldParser.first_icon(value)
      end

      def clean_description(value)
        CharacterSkills::FieldParser.clean_description(value)
      end

      def clean_markup(value)
        CharacterSkills::FieldParser.clean_markup(value)
      end

      def cant_recast?(text)
        text.to_s.match?(/Can't recast/i)
      end

      def one_time_use?(text)
        text.to_s.match?(/one[- ]time|can't be reactivated/i)
      end

      def auto_activate?(text)
        text.to_s.match?(/auto-activates|activates every/i)
      end

      def targets_all?(text)
        text.to_s.match?(/all allies|all foes|all .+ allies/i)
      end

      def status_ailment_id(status_id)
        status_lookup[:by_id][status_id]&.game_ailment_id
      end

      def clean_trigger_value(text)
        CharacterSkills::FieldParser.clean_trigger_value(text)
      end

      def split_top_level(text)
        CharacterSkills::FieldParser.split_top_level(text)
      end
    end
  end
end
