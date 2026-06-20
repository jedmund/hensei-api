# frozen_string_literal: true

module Granblue
  module Extractors
    # Repairs weapons whose wiki_raw is just a {{Weapon/Common/<Series>}} call with no skill
    # descriptions (Bahamut/Xeno/Militis/Exo/Cosmos/Celestial/…). Expands the template
    # (action=expandtemplates) to render the skill rows, then updates/creates the weapon's
    # skills from the FULL descriptions (which carry explicit values + the Multiplier/frame).
    #
    # Key-determined series (Dark Opus/Draconic/Destroyer/Ultima) are skipped — their per-key
    # skills are handled by the key→skill resolver, and the expanded HTML lists every key option.
    class ExpandedWeaponSkillImporter
      SKIP_SERIES = %w[dark-opus draconic draconic-providence ultima destroyer].freeze
      FRAME = { "normal" => "normal", "ex" => "ex", "omega" => "omega", "od" => "odious" }.freeze

      def self.run(limit: nil, throttle: 0.2)
        wiki = Granblue::Parsers::Wiki.new
        stats = Hash.new(0)
        scope = Weapon.includes(:weapon_series)
                      .where("wiki_raw IS NOT NULL AND wiki_raw <> '' AND wiki_raw NOT ILIKE ?", "%s1_desc=%")
        scope = scope.limit(limit) if limit

        scope.find_each do |w|
          next if SKIP_SERIES.include?(w.weapon_series&.slug)
          next unless w.wiki_raw.to_s =~ %r{\{\{Weapon/Common/}

          expanded = wiki.expand(w.wiki_raw)
          if expanded.blank?
            stats[:expand_failed] += 1
            next
          end
          # Key-determined weapons (anklet/pendulum/teluma) list every key option when expanded;
          # leave them to the key→skill resolver rather than creating all options as skills.
          if expanded.match?(/granted power with (an?|a) (anklet|pendulum|teluma|chain)|empowered by a chosen/i)
            stats[:key_determined] += 1
            next
          end
          skills = parse_skills(expanded)
          if skills.empty?
            stats[:no_skills] += 1
            next
          end
          persist(w, skills, stats)
          stats[:weapons] += 1
          sleep throttle if throttle.positive?
        end
        stats
      end

      # Rendered skill rows → [{name, description, series}] (one per distinct skill; highest tier
      # wins). Skips charge-attack/ougi and key-placeholder rows.
      def self.parse_skills(html)
        out = {}
        # Only the "Weapon Skills" table — exclude the charge-attack/ougi table above it, whose
        # skill-name row has no skill-desc and would shift the name/desc pairing.
        section = html[%r{weapon-skills.*}m] || html
        section.scan(%r{<td class="skill-name"[^>]*>(.*?)</td>.*?<td class="skill-desc"[^>]*>(.*?)</td>}m).each do |name_html, desc_html|
          name = clean(name_html)
          next if name.blank?

          frame = desc_html[/Multiplier:[^.]*?\b(Normal|EX|Omega|Od)\b/i, 1]&.downcase
          # Strip the "Multiplier:" annotation in both forms — linked ('''Multiplier:''' [[…]])
          # and plain ("Multiplier: Normal") — up to the next clause separator.
          stripped = desc_html.gsub(%r{'*Multiplier:'*\s*(?:\[\[[^\]]*\]\]|[\w .\-]+?)(?=[,.]|<|\z)}i, " ")
          desc = clean(stripped)
          next if desc.blank?
          next if desc.match?(/granted power with (an?|a) (anklet|pendulum|teluma)|empowered by a chosen/i)

          out[name] = { name: name, description: desc, series: FRAME[frame] }
        end
        out.values
      end

      # Update existing versions (matched by skill name) with the full description; append new
      # skills for ones we didn't have. Never deletes — safe to re-run.
      def self.persist(weapon, skills, stats)
        by_name = weapon.weapon_skills.includes(weapon_skill_versions: :skill)
                        .flat_map(&:weapon_skill_versions).index_by { |v| v.skill&.name_en }
        next_pos = (weapon.weapon_skills.maximum(:position) || -1) + 1

        skills.each do |s|
          if (v = by_name[s[:name]])
            v.skill.update!(description_en: s[:description]) if s[:description].present?
            v.update_columns(skill_series: s[:series]) if s[:series].present? && v.skill_series != s[:series]
            stats[:updated] += 1
          else
            ws = WeaponSkill.find_or_create_by!(weapon_granblue_id: weapon.granblue_id, position: next_pos)
            next_pos += 1
            skill = Skill.find_or_initialize_by(name_en: s[:name], skill_type: :weapon)
            skill.description_en = s[:description]
            skill.save!
            ws.weapon_skill_versions.create!(
              skill: skill, ordinal: 0, min_uncap: 3, skill_series: s[:series],
              main_hand_only: s[:description].match?(/when main weapon/i),
              mc_only: s[:description].match?(/\(mc only\)/i)
            )
            stats[:created] += 1
          end
        end
      end

      def self.clean(html)
        s = html.dup
        s.gsub!(%r{<br\s*/?>}i, " / ")
        s.gsub!(/\[\[[^\]|]*\|([^\]]*)\]\]/, '\1')
        s.gsub!(/\[\[([^\]]*)\]\]/, '\1')
        s.gsub!(/<[^>]+>/, "")
        s.gsub!(/'''|''/, "")
        s.gsub(/\s+/, " ").strip
      end

      private_class_method :parse_skills, :persist, :clean
    end
  end
end
