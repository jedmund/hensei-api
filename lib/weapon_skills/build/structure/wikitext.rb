# frozen_string_literal: true

module WeaponSkills
  module Build
    module Structure
      # Wikitext → the flat field hash the skill parse reads. A port of
      # Granblue::Parsers::WeaponParser#parse_string and its series-template merge, plus the
      # template defaults that merge used to skip (W2's parser cases P1 and P2):
      #
      #   page fields, then the template's literal fields on top (today's merge order: a
      #   template literal wins over the page's own value), then, for skill fields only:
      #   - `sN_lvl={{{sN_lvl|230}}}` when the page sets no `sN_lvl`: the default (P2, Illustrious)
      #   - `sN_4s_x={{{sN_4s_x|{{{sN_u1_x|}}}}}}` when the page has only `sN_u1_x`: the value
      #     moves to `sN_4s_x`, so a template literal `sN_4s_lvl=250` lands on that tier (P1)
      #   - `sN_lvl={{ #ifeq: {{ #var: v }} | a | b }}` with `#vardefine: v | {{{param|…}}}`, and
      #     `sN_lvl={{ #if: {{{param|}}} | 200 }}`: the evaluated level (P2 Epic, P6 Exo). An
      #     empty result keeps today's literal, which the level parse reads as 0.
      module Wikitext
        PLACEHOLDER = /\A\{\{\{.*\}\}\}\z/
        DISALLOWED = %w[#vardefine #lsth About].freeze
        SKILL_FIELD = /\A(?:en|jp)?s\d_/
        PARAM = /\{\{\{\s*([^{}|]+?)\s*(?:\|([^{}]*))?\}\}\}/
        ALIAS = /\A\{\{\{\s*([^{}|]+?)\s*\|\s*\{\{\{\s*([^{}|]+?)\s*\|\s*\}\}\}\s*\}\}\}\z/
        DEFAULT = /\A\{\{\{\s*([^{}|]+?)\s*\|([^{}|]*)\}\}\}\z/
        VARDEFINE = /\{\{\s*#vardefine:\s*([^{}|]+?)\s*\|([^{}]*)\}\}/
        VAR = /\{\{\s*#var:\s*([^{}|]+?)\s*\}\}/
        IFEQ = /\{\{\s*#ifeq:\s*([^{}|]*?)\s*\|\s*([^{}|]*?)\s*\|([^{}|]*)(?:\|([^{}|]*))?\}\}/
        IF = /\{\{\s*#if:\s*([^{}|]*?)\s*\|([^{}|]*)(?:\|([^{}|]*))?\}\}/

        module_function

        # WeaponParser#parse_string: `|key=value` lines up to "Gameplay Notes", the series
        # template name under :template, unresolved `{{{…}}}` placeholders skipped.
        def fields(string)
          data = {}
          each_line(string) do |line|
            if line.start_with?("{{")
              substr = line[2..].strip
              next if substr.start_with?(*DISALLOWED)

              if substr.start_with?("Weapon")
                substr = substr.split("|").first
                data[:template] = substr if substr != "Weapon"
                next
              end
            end
            pair = field(line) or next
            inline_fields(*pair).each do |key, value|
              next if value.match?(PLACEHOLDER)

              data[key] = value
            end
          end
          data
        end

        # As in MediaWiki, a template parameter's value ends at the first `|` outside `{{…}}`
        # and `[[…]]`; anything after it on the line is more parameters. White Hawk's page has
        # `|s1_desc=…|s2_name=Tsunami's Might` on one line, and Marriage Sharkbell's s1_desc
        # ends in empty `||` parameters. → [[key, value], …]
        def inline_fields(key, value)
          segments = top_level_split(value)
          extra = segments.drop(1).filter_map do |segment|
            k, v = segment.split("=", 2).map(&:strip)
            [k, v] if v && k.match?(/\A[A-Za-z0-9_]+\z/)
          end
          [[key, segments.first.strip], *extra]
        end

        def top_level_split(text)
          parts = [+""]
          depth = 0
          i = 0
          while i < text.length
            two = text[i, 2]
            if ["{{", "[["].include?(two)
              depth += 1
              parts.last << two
              i += 2
            elsif ["}}", "]]"].include?(two) && depth.positive?
              depth -= 1
              parts.last << two
              i += 2
            elsif text[i] == "|" && depth.zero?
              parts << +""
              i += 1
            else
              parts.last << text[i]
              i += 1
            end
          end
          parts
        end

        # Page fields merged with the series template's, with the template defaults above.
        def merge_template(page, template_text)
          merged = page.merge(fields(template_text))
          vars = vardefines(template_text, page)
          template_fields(template_text).each do |key, value|
            next unless key.match?(SKILL_FIELD)

            apply_template_field(merged, page, key, value, vars)
          end
          merged
        end

        def apply_template_field(merged, page, key, value, vars)
          if (m = value.match(ALIAS)) && m[1] == key
            alt = m[2]
            return if page.key?(key) || page[alt].blank?

            merged[key] = page[alt]
            merged.delete(alt)
          elsif key.end_with?("_lvl") && (m = value.match(DEFAULT)) && m[1] == key
            merged[key] = m[2].strip if !page.key?(key) && m[2].strip.present?
          elsif key.end_with?("_lvl") && value.match?(/#if(?:eq)?:/)
            evaluated = evaluate(value, vars, page)
            merged[key] = evaluated if evaluated.present? && !evaluated.include?("{{")
          end
        end

        # key → the field's whole value, continuation lines included (a `{{ #switch: … }}`
        # spread over several lines), for fields that start at the line's first column.
        def full_values(string)
          out = {}
          key = nil
          each_line(string) do |line|
            if (m = line.match(/\A\|([^=|{}\s]+)\s*=(.*)\z/))
              key = m[1]
              out[key] = m[2].strip
            elsif key && !line.start_with?("{{", "}}")
              out[key] = "#{out[key]}\n#{line}"
            else
              key = nil
            end
          end
          out
        end

        # Every `|key=value` line of a template, placeholders included.
        def template_fields(string)
          out = []
          each_line(string) do |line|
            pair = field(line) or next
            out << pair
          end
          out
        end

        def each_line(string)
          string.to_s.split("\n").each do |line|
            break if line.include?("Gameplay Notes")

            yield line
          end
        end

        def field(line)
          return nil unless line[0] == "|" && line.size > 2

          key, value = line[1..].split("=", 2).map(&:strip)
          value ? [key, value] : nil
        end

        # `{{ #vardefine: name | value }}` definitions, with the page's parameters substituted.
        def vardefines(template_text, page)
          substitute_params(template_text.to_s, page).scan(VARDEFINE).to_h { |name, value| [name.strip, value.strip] }
        end

        def evaluate(value, vars, page)
          text = substitute_params(value, page)
          conditionals(text.gsub(VAR) { vars[Regexp.last_match(1).strip].to_s })
        end

        # `{{ #ifeq: a | b | then | else }}` and `{{ #if: test | then | else }}` whose
        # arguments are already plain text.
        def conditionals(text)
          text = text.gsub(IFEQ) do
            a, b, yes, no = Regexp.last_match.captures
            (a.strip == b.strip ? yes : no.to_s).strip
          end
          text.gsub(IF) do
            test, yes, no = Regexp.last_match.captures
            (test.strip.empty? ? no.to_s : yes).strip
          end.strip
        end

        # `{{{param|default}}}` → the page's value, else the default (innermost first).
        def substitute_params(text, page)
          previous = nil
          while previous != text
            previous = text
            text = text.gsub(PARAM) do
              name = Regexp.last_match(1)
              page.key?(name) ? page[name].to_s : Regexp.last_match(2).to_s
            end
          end
          text
        end
      end
    end
  end
end
