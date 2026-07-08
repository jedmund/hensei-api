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
      # Aura-word-less special series re-expanded even when complete, to capture the wiki
      # Multiplier frame (the heuristic can't infer it). Start with the non-summon-boosted ones.
      SPECIAL_SERIES = %w[bahamut celestial].freeze
      FRAME = { "normal" => "normal", "ex" => "ex", "omega" => "omega", "od" => "odious" }.freeze

      def self.run(limit: nil, throttle: 0.2)
        wiki = Granblue::Parsers::Wiki.new
        stats = Hash.new(0)
        # Weapons needing repair: series-template weapons that are either incomplete (no skill
        # descriptions) OR carry garbled skills (unresolved {{WeaponElement}}/{{ #var }} templates
        # the original parser stored verbatim). Expanding resolves both.
        garbled_ids = WeaponSkill.joins(weapon_skill_versions: :skill)
                                 .where("skills.name_en LIKE ?", "%{{%")
                                 .distinct.pluck(:weapon_granblue_id)
        # Special series whose skills lack aura-words (so the frame heuristic is unreliable) and
        # need the wiki Multiplier captured even when already complete — e.g. Celestial/Bahamut.
        special_series_ids = WeaponSeries.where(slug: SPECIAL_SERIES).select(:id)
        scope = Weapon.includes(:weapon_series)
                      .where("(wiki_raw IS NOT NULL AND wiki_raw <> '' AND wiki_raw NOT ILIKE ?) " \
                             "OR granblue_id IN (?) OR weapon_series_id IN (?)",
                             "%s1_desc=%", garbled_ids, special_series_ids)
        scope = scope.limit(limit) if limit

        scope.find_each do |w|
          next if SKIP_SERIES.include?(w.weapon_series&.slug)

          result = repair_weapon(w, wiki: wiki, stats: stats)
          stats[result] += 1 unless result == :repaired
          stats[:weapons] += 1 if result == :repaired
          sleep throttle if result == :repaired && throttle.positive?
        end
        stats
      end

      # Repair ONE series-template weapon by expanding its wiki_raw (network) and
      # rebuilding its skills from the rendered rows. Also used by EntityReparser,
      # where a raw structural parse would regress the expansion repair.
      def self.repair_weapon(weapon, wiki: Granblue::Parsers::Wiki.new, stats: Hash.new(0), force: false)
        return :not_template unless force || weapon.wiki_raw.to_s.include?('{{Weapon/Common/')

        expanded = wiki.expand(weapon.wiki_raw)
        return :expand_failed if expanded.blank?
        # Key-determined weapons (anklet/pendulum/teluma) list every key option when expanded;
        # leave them to the key→skill resolver rather than creating all options as skills.
        if expanded.match?(/granted power with (an?|a) (anklet|pendulum|teluma|chain)|empowered by a chosen/i) &&
           !expanded.match?(KEY_SLOT) # pure key pages bail; mixed pages persist base skills and skip key rows
          return :key_determined
        end

        skills = parse_skills(expanded)
        return :no_skills if skills.empty?

        persist(weapon, skills, stats)
        apply_gameplay_notes(weapon, expanded, stats)
        :repaired
      end

      # A skill row whose desc is one of these placeholders marks a KEY SLOT — every skill row
      # AFTER it lists that slot's key options (Dark Opus pendulum/teluma, Destroyer anklet),
      # which are equipped-key-determined, NOT always-on base skills. Captures the key type.
      KEY_SLOT = /granted power with (?:an? |a )?(anklet|pendulum|teluma)
                  |empowered by a chosen (pendulum|teluma)
                  |a (gate) to the summits|(?:locked|sealed) within (ultima)/xi

      # Rendered skill rows → [{name, description, series, key_type}] (one per distinct skill;
      # highest tier wins). key_type is nil for base skills, else "anklet"/"pendulum"/"teluma"
      # for skills listed under a key-slot placeholder. Skips charge-attack/ougi rows.
      def self.parse_skills(html)
        out = {}
        # Only the "Weapon Skills" table — exclude the charge-attack/ougi table above it, whose
        # skill-name row has no skill-desc and would shift the name/desc pairing.
        section = html[/weapon-skills.*/m] || html
        key_type = nil
        row_re = %r{<td class="skill-name"[^>]*>(.*?)</td>.*?<td class="skill-desc"[^>]*>(.*?)</td>}m
        prev_end = 0
        section.enum_for(:scan, row_re).each do
          match = Regexp.last_match
          name_html = match[1]
          desc_html = match[2]
          # "Alternate skill N" labels between rows mark equipped-key options (Ultima
          # gauph slots list options BEFORE their placeholder row — order can't be trusted)
          alternate = section[prev_end...match.begin(0)].to_s.match?(/Alternate skill/i)
          prev_end = match.end(0)
          name = clean(name_html)
          next if name.blank?

          frame = desc_html[/Multiplier:[^.]*?\b(Normal|EX|Omega|Od)\b/i, 1]&.downcase
          # Strip the "Multiplier:" annotation in both forms — linked ('''Multiplier:''' [[…]])
          # and plain ("Multiplier: Normal") — up to the next clause separator.
          stripped = desc_html.gsub(/'*Multiplier:'*\s*(?:\[\[[^\]]*\]\]|[\w .\-]+?)(?=[,.]|<|\z)/i, " ")
          desc = clean(stripped)
          next if desc.blank?

          if (m = desc.match(KEY_SLOT)) # the placeholder itself — skip, but every later row is a key
            key_type = m.captures.compact.first.to_s.downcase
            next
          end

          out[name] = { name: name, description: desc, series: FRAME[frame],
                        key_type: alternate ? (key_type || "key") : key_type }
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
          next if s[:key_type] # key options are equipped-key-determined, not base versions

          if (v = by_name[s[:name]])
            v.skill.update!(description_en: s[:description]) if s[:description].present?
            # multiplier_frame is the authoritative wiki frame; skill_series stays the heuristic.
            v.update_columns(multiplier_frame: s[:series]) if s[:series].present? && v.multiplier_frame != s[:series]
            stats[:updated] += 1
          else
            ws = WeaponSkill.find_or_create_by!(weapon_granblue_id: weapon.granblue_id, position: next_pos)
            next_pos += 1
            skill = Skill.find_or_initialize_by(name_en: s[:name], skill_type: :weapon)
            skill.description_en = s[:description]
            skill.save!
            ws.weapon_skill_versions.create!(
              skill: skill, ordinal: 0, min_uncap: 3, skill_series: s[:series], multiplier_frame: s[:series],
              main_hand_only: s[:description].match?(/when main weapon/i),
              mc_only: s[:description].match?(/\(mc only\)/i)
            )
            stats[:created] += 1
          end
        end

        cleanup_garbled(weapon, stats)
      end

      # Parse the expanded "Gameplay Notes" prose (where community-computed values live) and write
      # version-linked effects for the skills that have them — per-count (Voltage), per-specialty
      # (Cloud), flat. These carry the numbers the skill blurbs omit.
      def self.apply_gameplay_notes(weapon, expanded, stats)
        notes = Granblue::Parsers::GameplayNotesParser.parse(expanded)
        return if notes.empty?

        by_name = weapon.weapon_skills.includes(weapon_skill_versions: :skill)
                        .flat_map(&:weapon_skill_versions).index_by { |v| v.skill&.name_en }
        notes.each do |skill_name, info|
          v = by_name[skill_name] or next
          WeaponSkillEffect.where(weapon_skill_version_id: v.id,
                                  scaling_kind: %w[per_grid_count specialty_scaled]).delete_all
          info[:clauses].each { |c| create_notes_effect(v, skill_name, info[:frame], c, stats) }
        end
      end

      def self.create_notes_effect(version, skill_name, frame, clause, stats)
        attrs = { weapon_skill_version_id: version.id, modifier: skill_name, boost_type: clause[:boost_type],
                  series: frame, value_unit: "percent", applies_to: "element_allies", stacking: "additive" }
        case clause[:scaling]
        when :per_count
          WeaponSkillEffect.create!(attrs.merge(scaling_kind: "per_grid_count", value: clause[:value],
                                                count_basis: "weapon_type", total_cap: clause[:max],
                                                shared_cap_group: clause[:shared_cap]))
        when :per_specialty
          WeaponSkillEffect.create!(attrs.merge(scaling_kind: "specialty_scaled",
                                                condition: { "specialties" => clause[:by_specialty] }))
        when :flat
          WeaponSkillEffect.create!(attrs.merge(scaling_kind: "static", value: clause[:value]))
        end
        stats[:notes_effects] += 1
      rescue ActiveRecord::RecordInvalid => e
        stats[:notes_invalid] += 1
        Rails.logger.warn("gameplay-notes effect invalid (#{skill_name}/#{clause[:boost_type]}): #{e.message}")
      end

      # Drop stale versions whose skill name still holds an unresolved {{…}} template (the
      # pre-expansion import artifact) now that the resolved skills have been written.
      def self.cleanup_garbled(weapon, stats)
        weapon.weapon_skills.includes(weapon_skill_versions: :skill).each do |ws|
          ws.weapon_skill_versions.each do |v|
            next unless v.skill&.name_en&.include?("{{")

            WeaponSkillDatum.where(weapon_skill_version_id: v.id).delete_all
            WeaponSkillEffect.where(weapon_skill_version_id: v.id).delete_all
            v.destroy
            stats[:garbled_removed] += 1
          end
          ws.destroy if ws.weapon_skill_versions.reload.empty?
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

      private_class_method :parse_skills, :persist, :apply_gameplay_notes, :create_notes_effect, :cleanup_garbled, :clean
    end
  end
end
