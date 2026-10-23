# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Stateless heuristics that classify a skill from its text: variant roles,
      # trigger type/value, and progression (uncap/transcendence) inference. Pure
      # functions over wiki text/labels — no character or graph state.
      module InferenceRules
        # A skill relearned at or past this level is a Transcendence upgrade.
        TRANSCENDENCE_MIN_LEVEL = 120
        # Level threshold => Transcendence stage (checked high to low).
        TRANSCENDENCE_STAGE_LEVELS = { 150 => 5, TRANSCENDENCE_MIN_LEVEL => 1 }.freeze

        module_function

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

        def base_role(effdesc, option)
          text = effdesc.to_s
          return 'conditional' if text.match?(/effect changes based/i) && option.to_s.exclude?('options')

          'base'
        end

        def ougi_progression(key, label)
          return ['base', 4, nil] if key == 'ougi'

          label = label.to_s
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

        def enhanced_role(level)
          level >= TRANSCENDENCE_MIN_LEVEL ? 'transcendence_upgrade' : 'enhanced'
        end

        def transcendence_stage(level)
          TRANSCENDENCE_STAGE_LEVELS.each { |threshold, stage| return stage if level >= threshold }

          nil
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
          FieldParser.clean_markup(text).gsub(/\{\{status\|([^|}]+).*?\}\}/i, '\\1')
        end

        def relation_for_role(role)
          { 'option' => 'option_of', 'form_alt' => 'form_counterpart', 'transform_alt' => 'transforms_to' }[role]
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
      end
    end
  end
end
