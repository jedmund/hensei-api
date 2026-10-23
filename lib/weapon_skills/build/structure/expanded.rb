# frozen_string_literal: true

module WeaponSkills
  module Build
    module Structure
      # The rendered "Weapon Skills" table of a stored expansion → one row per distinct skill
      # name (the highest tier wins). A port of ExpandedWeaponSkillImporter.parse_skills.
      #
      # KEY_SLOT is written with escaped spaces: the original's /x flag dropped them, so it
      # never matched and key options were never flagged.
      module Expanded
        KEY_SLOT = /granted\ power\ with\ (?:an?\ )?(anklet|pendulum|teluma|chain)
                    |empowered\ by\ a\ chosen\ (pendulum|teluma)
                    |a\ (gate)\ to\ the\ summits
                    |(?:locked|sealed)\ within\ (ultima)/xi
        ROW = %r{<td class="skill-name"[^>]*>(.*?)</td>.*?<td class="skill-desc"[^>]*>(.*?)</td>}m
        FRAME = { "normal" => "normal", "ex" => "ex", "omega" => "omega", "od" => "odious" }.freeze

        module_function

        # → [{ name:, description:, series:, key_type: }]; key_type is nil for base skills.
        def rows(html)
          out = {}
          section = html[/weapon-skills.*/m] || html
          key_type = nil
          prev_end = 0
          section.enum_for(:scan, ROW).each do
            match = Regexp.last_match
            # "Alternate skill N" labels mark equipped-key options (Ultima lists them before
            # their placeholder row, so order alone can't be trusted)
            alternate = section[prev_end...match.begin(0)].to_s.match?(/Alternate skill/i)
            prev_end = match.end(0)
            name = clean(match[1])
            next if name.blank?

            desc_html = match[2]
            frame = desc_html[/Multiplier:[^.]*?\b(Normal|EX|Omega|Od)\b/i, 1]&.downcase
            stripped = desc_html.gsub(/'*Multiplier:'*\s*(?:\[\[[^\]]*\]\]|[\w .-]+?)(?=[,.]|<|\z)/i, " ")
            desc = clean(stripped)
            next if desc.blank?

            if (m = desc.match(KEY_SLOT)) # the placeholder itself; every later row is a key option
              key_type = m.captures.compact.first.to_s.downcase
              next
            end

            out[name] = { name: name, description: desc, series: FRAME[frame],
                          key_type: alternate ? (key_type || "key") : key_type }
          end
          out.values
        end

        def clean(html)
          s = html.dup
          # Status icons expand to [[File:…|25px|link=X]] plus a hidden tooltip span; keeping
          # either garbles the text ("25px|link=BurnedBurnedHP is lowered…").
          s.gsub!(%r{<span class="hr"></span>}i, "")
          s.gsub!(%r{<span class="tooltiptext">.*?</span>}im, "")
          s.gsub!(/\[\[(?:File|Image):[^\]]*\]\]/i, "")
          s.gsub!(%r{<br\s*/?>}i, " / ")
          s.gsub!(/\[\[[^\]|]*\|([^\]]*)\]\]/, '\1')
          s.gsub!(/\[\[([^\]]*)\]\]/, '\1')
          s.gsub!(/<[^>]+>/, "")
          s.gsub!(/'''|''/, "")
          s.gsub(/\s+/, " ").strip
        end

        def main_hand_only_description?(description)
          text = description.to_s
          clauses = text.split(%r{\s+/\s+})
          (clauses.length > 1 ? clauses.first : text).match?(/when main weapon/i)
        end
      end
    end
  end
end
