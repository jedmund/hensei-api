# frozen_string_literal: true

require 'bigdecimal/util'

module Granblue
  module Parsers
    module CharacterSkills
      # Parses a skill's raw English description into ordered effect rows
      # (granted/inflicted statuses, damage, heal/dispel), resolving statuses
      # against a preloaded lookup. Accumulates the names it can't resolve.
      class EffectParser
        TT_TEMPLATE = /\{\{tt\|([\d.]+)%\|[^}]+\}\}/i

        # Window of surrounding text used to classify an individual effect clause.
        CONTEXT_RADIUS = 80
        CONTEXT_WIDTH = 180

        # When a clause yields no subject, default by effect type (the clear cases).
        DEFAULT_TARGETS = { 'grant_status' => 'caster', 'inflict_status' => 'one_foe', 'field_effect' => 'field' }.freeze

        STACKING_FRAMES = {
          'n' => 'normal',
          'normal' => 'normal',
          'smn' => 'summon',
          'summon' => 'summon',
          'u' => 'unique',
          'us' => 'unique',
          'unique' => 'unique',
          'seraphic' => 'seraphic',
          'ex' => 'ex',
          'ass' => 'assassin',
          'assassin' => 'assassin'
        }.freeze

        attr_reader :unmatched_statuses

        def initialize(status_lookup)
          @status_lookup = status_lookup
          @unmatched_statuses = Set.new
        end

        def parse(effdesc)
          description = effdesc.to_s
          clauses = clause_targets(description)
          effects = []
          ordinal = 0

          scan_with_offsets(description, CharacterWikiData::STATUS_TEMPLATE).each do |inner, offset|
            ordinal += 1
            raw = "{{status|#{inner}}}"
            parts = inner.split('|')
            name = FieldParser.clean_status_name(parts.shift)
            params = template_params(parts)
            status = find_status(name)
            @unmatched_statuses << name if status.nil?
            duration = duration_from_status(params['t'])
            effect_type = effect_type_for_status(local_context(description, offset), status)

            effects << {
              ordinal: ordinal,
              effect_type: effect_type,
              target: target_at(clauses, offset) || DEFAULT_TARGETS[effect_type],
              status_id: status&.id,
              amount: params['a'],
              amount_max: params['am'],
              duration_value: duration[:value],
              duration_unit: duration[:unit],
              accuracy: params['acc'],
              stacking_frame: STACKING_FRAMES[params['s'].to_s.downcase],
              raw: raw
            }.compact
          end

          scan_with_offsets(description, TT_TEMPLATE).each do |pct, offset|
            ordinal += 1
            context = local_context(description, offset)
            effects << {
              ordinal: ordinal,
              effect_type: 'deal_damage',
              target: target_at(clauses, offset),
              damage_pct: pct.to_d,
              damage_cap: damage_cap(context),
              hit_count: hit_count(context),
              raw: pct
            }.compact
          end

          # NOTE: heal/dispel are coarse whole-description heuristics — at most one
          # of each per version. Refine to multi-instance parsing if fidelity demands it.
          effects << other_effect(description, clauses, ordinal + 1, 'dispel', /remove \d+ buff/i)
          effects << other_effect(description, clauses, ordinal + 2, 'heal', /restore .*hp|healing cap/i)
          effects.compact
        end

        private

        attr_reader :status_lookup

        # A clause (≈ one line) has a single subject that governs every effect in it,
        # whether the subject leads ("All allies gain …") or trails ("inflict … on a
        # foe"). Subject-less continuation lines inherit the previous clause's subject.
        def clause_targets(description)
          position = 0
          last = nil
          description.split(/(\n)/).filter_map do |segment|
            range = position...(position + segment.length)
            position += segment.length
            next if segment == "\n"

            target = subject_in_clause(segment) || last
            last = target if target
            [range, target]
          end
        end

        def subject_in_clause(text)
          normalized = text.downcase
          return 'all_allies' if normalized.match?(/all (?:[a-z]+ )?allies/)
          return 'all_foes' if normalized.match?(/all foes|all enemies/)
          return 'one_ally' if normalized.match?(/\b(?:an|another|one) (?:[a-z]+ )?ally\b/)
          return 'one_foe' if normalized.match?(/\b(?:a|one) foe\b|\ban enemy\b|on the foe/)
          return 'caster' if normalized.match?(/\bgain\b|\bcaster\b|\bown\b/)

          nil
        end

        def target_at(clauses, offset)
          clauses.find { |range, _| range.cover?(offset) }&.last
        end

        def effect_type_for_status(context, status)
          return 'field_effect' if status&.category == 'field'

          normalized = context.to_s.downcase
          if status&.category == 'debuff' || normalized.match?(/inflict|foe|enemy|lowered|delay/)
            'inflict_status'
          else
            'grant_status'
          end
        end

        def scan_with_offsets(text, regex)
          text.to_enum(:scan, regex).map { [Regexp.last_match(1), Regexp.last_match.begin(0)] }
        end

        def local_context(description, offset)
          start = [offset - CONTEXT_RADIUS, 0].max
          description[start, CONTEXT_WIDTH].to_s
        end

        def damage_cap(text)
          text.to_s[/Damage cap:\s*~?([\d,]+)/i, 1]&.delete(',')&.to_i
        end

        def hit_count(text)
          text.to_s[/(\d+)-hit/i, 1]&.to_i
        end

        def other_effect(description, clauses, ordinal, effect_type, matcher)
          match = matcher.match(description)
          return unless match

          {
            ordinal: ordinal,
            effect_type: effect_type,
            target: target_at(clauses, match.begin(0)),
            raw: match[0]
          }.compact
        end

        def template_params(parts)
          parts.each_with_object({}) do |part, params|
            key, value = part.split('=', 2)
            params[key.to_s.strip.downcase] = value.to_s.strip if value
          end
        end

        def duration_from_status(value)
          text = value.to_s
          case text
          when /\A(\d+)T\z/i then { value: Regexp.last_match(1).to_i, unit: 'turns' }
          when /\A(\d+)s\z/i then { value: Regexp.last_match(1).to_i, unit: 'seconds' }
          when 'i' then { value: nil, unit: 'indefinite' }
          when '' then { value: nil, unit: nil }
          else { value: nil, unit: text.match?(/time/i) ? 'one_time' : nil }
          end
        end

        def find_status(name)
          status_lookup[:by_name][name.to_s.downcase]
        end
      end
    end
  end
end
