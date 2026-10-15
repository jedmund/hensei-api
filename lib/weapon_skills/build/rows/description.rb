# frozen_string_literal: true

module WeaponSkills
  module Build
    module Rows
      # The description text the row compiler parses for a version, read the way the
      # extractor does today: the weapon's wiki_raw sN_desc (it carries the numbers that the
      # abbreviated Skill#description_en drops), else Skill#description_en.
      #
      # The wiki_raw field is the first tier ("", 4s, 5s, u1, u2, u3) whose sN_name equals the
      # version's skill name, so two tiers that share a name both read the lower tier's text.
      module Description
        TIERS = ["", "4s", "5s", "u1", "u2", "u3"].freeze

        module_function

        # position: the slot's 0-based position.
        def text(wiki_raw:, position:, name:, fallback:)
          full_description(wiki_raw, position, name).presence || fallback
        end

        def full_description(wiki_raw, position, name)
          return nil if wiki_raw.blank?

          pos = position.to_i + 1
          TIERS.each do |tier|
            field = "s#{pos}#{"_#{tier}" unless tier.empty?}"
            return wiki_field(wiki_raw, "#{field}_desc") if wiki_field(wiki_raw, "#{field}_name") == name
          end
          nil
        end

        def wiki_field(raw, field)
          raw[/\|#{Regexp.escape(field)}=(.*?)(?:\n\||\z)/m, 1]&.strip
        end
      end
    end
  end
end
