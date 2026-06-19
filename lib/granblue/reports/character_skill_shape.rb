# frozen_string_literal: true

module Granblue
  module Reports
    # Renders the parsed character-skill graph for a character into a readable
    # shape, for eyeballing whether the parser extracts structure correctly.
    # Also used to rank characters by structural complexity so we can focus
    # evaluation on the hardest cases.
    class CharacterSkillShape
      # Roles beyond a plain progression line that exercise the variant heuristics.
      SPECIAL_ROLES = %w[transform_alt option form_alt conditional uncap_upgrade transcendence_upgrade].freeze

      class << self
        # Parses every character with wiki_raw, returns the `limit` most complex
        # as [character, report] pairs (highest score first).
        def most_complex(limit: 15)
          lookup = Granblue::Parsers::CharacterSkillParser.build_status_lookup
          scored = Character.where.not(wiki_raw: [nil, '']).find_each.map do |character|
            report = Granblue::Parsers::CharacterSkillParser.new(character, status_lookup: lookup).parse(persist: false)
            { character: character, report: report, score: complexity(report) }
          end
          scored.sort_by { |row| -row[:score] }.first(limit)
        end

        # Parses the given granblue_ids, returns [character, report] pairs.
        def for_ids(granblue_ids)
          lookup = Granblue::Parsers::CharacterSkillParser.build_status_lookup
          Character.where(granblue_id: granblue_ids).map do |character|
            report = Granblue::Parsers::CharacterSkillParser.new(character, status_lookup: lookup).parse(persist: false)
            { character: character, report: report, score: complexity(report) }
          end
        end

        def complexity(report)
          counts = report[:counts]
          special = all_versions(report).count { |version| SPECIAL_ROLES.include?(version[:attrs][:variant_role]) }
          counts[:versions] + (2 * counts[:links]) + (5 * special)
        end

        def render(rows, status_lookup: nil)
          lookup = status_lookup || Granblue::Parsers::CharacterSkillParser.build_status_lookup
          [summary_table(rows), *rows.map { |row| new(row, lookup).render }].join("\n")
        end

        def all_versions(report)
          report[:slots].flat_map { |slot| slot[:versions] }
        end

        private

        def summary_table(rows)
          lines = ['## Summary (ranked by structural complexity)', '',
                   '| # | Character | id | score | slots | versions | effects | links | game data | unmatched |',
                   '|---|---|---|---|---|---|---|---|---|---|']
          rows.each_with_index do |row, index|
            c = row[:character]
            counts = row[:report][:counts]
            lines << "| #{index + 1} | #{c.name_en} | #{c.granblue_id} | #{row[:score]} | " \
                     "#{counts[:slots]} | #{counts[:versions]} | #{counts[:effects]} | #{counts[:links]} | " \
                     "#{game_data_tag(c)} | #{row[:report][:unmatched_statuses].size} |"
          end
          "#{lines.join("\n")}\n"
        end

        def game_data_tag(character)
          tags = []
          tags << 'en' if character.game_raw_en.present?
          tags << 'jp' if character.game_raw_jp.present?
          tags.empty? ? '—' : tags.join('+')
        end
      end

      def initialize(row, status_lookup)
        @character = row[:character]
        @report = row[:report]
        @status_lookup = status_lookup
      end

      def render
        out = ["\n## #{@character.name_en} — #{@character.granblue_id}", counts_line, '']
        @report[:slots].each { |slot| out.concat(render_slot(slot)) }
        out.concat(render_links)
        out.concat(render_diagnostics)
        out.join("\n")
      end

      private

      def counts_line
        c = @report[:counts]
        "`slots #{c[:slots]} · versions #{c[:versions]} · effects #{c[:effects]} · links #{c[:links]}`"
      end

      def render_slot(slot)
        attrs = slot[:attrs]
        header = "### #{attrs[:kind]} #{attrs[:position]}#{action_suffix(attrs[:game_action_id])}"
        [header, *slot[:versions].flat_map { |version| render_version(version) }, '']
      end

      def action_suffix(action_id)
        action_id.present? ? " · game_action #{action_id}" : ''
      end

      def render_version(version)
        attrs = version[:attrs]
        lines = ["- v#{attrs[:ordinal]} [#{attrs[:variant_role]}#{trigger_tag(attrs)}#{gate_tag(attrs)}] " \
                 "\"#{attrs[:name_en]}\"#{jp_tag(attrs[:name_jp])}#{timing(attrs)}#{flags(attrs)}"]
        lines.concat(render_description(attrs))
        version[:effects].each { |effect| lines << "    • #{render_effect(effect)}" }
        lines
      end

      # The API serves description_en/jp verbatim as { en:, ja: }, so this is the
      # exact display text a client would render.
      def render_description(attrs)
        description_lines('en', attrs[:description_en]) + description_lines('ja', attrs[:description_jp])
      end

      def description_lines(label, text)
        rows = text.to_s.split("\n").map(&:strip).reject(&:empty?)
        return [] if rows.empty?

        ["    #{label}: #{rows.first}", *rows.drop(1).map { |row| "        #{row}" }]
      end

      def trigger_tag(attrs)
        return '' if attrs[:trigger_type].blank? || attrs[:trigger_type] == 'none'

        value = attrs[:trigger_value].present? ? " \"#{attrs[:trigger_value]}\"" : ''
        " | #{attrs[:trigger_type]}#{value}"
      end

      def gate_tag(attrs)
        parts = []
        parts << "@#{attrs[:unlock_level]}" if attrs[:unlock_level]
        parts << "uncap #{attrs[:min_uncap]}" if attrs[:min_uncap] && attrs[:min_uncap] != 4
        parts << "transc #{attrs[:transcendence_stage]}" if attrs[:transcendence_stage]
        parts.empty? ? '' : " | #{parts.join(' ')}"
      end

      def jp_tag(name_jp)
        name_jp.present? ? " / #{name_jp}" : ''
      end

      def timing(attrs)
        parts = []
        parts << "cd #{attrs[:cooldown]}" if attrs[:cooldown]
        parts << "init #{attrs[:initial_cooldown]}" if attrs[:initial_cooldown]
        if attrs[:duration_unit].present? && attrs[:duration_unit] != 'none'
          parts << "dur #{[attrs[:duration_value], attrs[:duration_unit]].compact.join(' ')}"
        end
        parts.empty? ? '' : "  (#{parts.join(', ')})"
      end

      def flags(attrs)
        set = %i[cant_recast one_time_use auto_activate mimicable targets_all].select { |flag| attrs[flag] }
        set.empty? ? '' : "  {#{set.join(', ')}}"
      end

      def render_effect(effect)
        case effect[:effect_type]
        when 'deal_damage'
          "deal_damage → #{effect[:target] || '?'}  #{effect[:damage_pct]}%" \
          "#{" hit #{effect[:hit_count]}" if effect[:hit_count]}#{" cap #{effect[:damage_cap]}" if effect[:damage_cap]}"
        when 'grant_status', 'inflict_status'
          "#{effect[:effect_type]} → #{effect[:target] || '?'}  #{status_name(effect[:status_id])}#{status_params(effect)}"
        else
          "#{effect[:effect_type]} → #{effect[:target] || '?'}#{status_params(effect)}"
        end
      end

      def status_params(effect)
        parts = []
        parts << "a=#{effect[:amount]}" if effect[:amount]
        parts << "am=#{effect[:amount_max]}" if effect[:amount_max]
        parts << "t=#{[effect[:duration_value], effect[:duration_unit]].compact.join(' ')}" if effect[:duration_unit]
        parts << "acc=#{effect[:accuracy]}" if effect[:accuracy]
        parts << "s=#{effect[:stacking_frame]}" if effect[:stacking_frame]
        parts.empty? ? '' : "  (#{parts.join(' ')})"
      end

      def status_name(status_id)
        return '⟨unmatched⟩' if status_id.blank?

        status = @status_lookup[:by_id][status_id]
        return "⟨#{status_id}⟩" unless status

        [status.name_en, status.name_jp].compact.reject(&:empty?).join(' / ')
      end

      def render_links
        return [] if @report[:links].empty?

        labels = version_labels
        ['### links',
         *@report[:links].map do |link|
           "- #{labels[link[:from_version_key]]} --#{link[:relation]}--> #{labels[link[:to_version_key]]}"
         end,
         '']
      end

      def version_labels
        @report[:slots].each_with_object({}) do |slot, map|
          slot[:versions].each do |version|
            map[version[:key]] = "#{slot[:attrs][:kind]} #{slot[:attrs][:position]}:\"#{version[:attrs][:name_en]}\""
          end
        end
      end

      def render_diagnostics
        lines = []
        lines << "**unmatched statuses:** #{@report[:unmatched_statuses].join(', ')}" if @report[:unmatched_statuses].any?
        lines << "**missing fields:** #{@report[:missing_fields].join(', ')}" if @report[:missing_fields].any?
        if @report[:cross_validation].any?
          lines << "**cross-validation gaps (gamedata ailment ids not parsed as statuses):**"
          @report[:cross_validation].each do |gap|
            lines << "  - #{gap[:slot][:kind]} #{gap[:slot][:position]} \"#{gap[:version]}\": #{gap[:missing_game_ailment_ids].join(', ')}"
          end
        end
        lines.empty? ? [] : ['### diagnostics', *lines, '']
      end
    end
  end
end
