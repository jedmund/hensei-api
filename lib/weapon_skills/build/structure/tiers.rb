# frozen_string_literal: true

module WeaponSkills
  module Build
    module Structure
      # Field hash → skill slots and their tiers. A port of WeaponParser#extract_weapon_skills,
      # #discover_skill_versions, #tier_for, #build_skill_entry, #resolve_ifeq_name,
      # #size_from_description and #main_hand_only_description?.
      #
      # One change: tiers with the same unlock level are ordered by their suffix (base, 4s,
      # 5s…, u1, u2…), where the old sort left ties to the sort algorithm.
      module Tiers
        SIZE_KEYWORD = /\b(unworldly|massive|big|medium|small)\b/i
        ELEMENT_SUFFIX = /:\s*(Fire|Water|Earth|Wind|Light|Dark)\z/

        module_function

        # → [{ position:, versions: [entry] }], one per occupied slot (position is 0-based)
        def slots(hash)
          (1..4).filter_map do |slot|
            versions = versions(hash, slot)
            next if versions.empty?

            { position: slot - 1, versions: versions }
          end
        end

        def versions(hash, slot)
          suffixes = []
          suffixes << nil if hash["s#{slot}_name"].present?
          hash.each_key do |key|
            next unless key.to_s =~ /\As#{slot}_(\d+s|u\d+)_name\z/
            next unless hash[key].present?

            suffixes << Regexp.last_match(1)
          end

          suffixes.uniq
                  .filter_map { |suffix| entry(hash, slot, suffix: suffix) }
                  .sort_by { |entry| [entry[:unlock_level] || 0, suffix_rank(entry[:suffix])] }
                  .each_with_index
                  .map { |entry, idx| entry.merge(ordinal: idx) }
        end

        def suffix_rank(suffix)
          return [0, 0] if suffix.nil?

          m = suffix.match(/\A(\d+)s\z/) and return [1, m[1].to_i]
          [2, suffix[/\d+/].to_i]
        end

        # nil / ≤100 → base (3) · ≤150 → FLB (4) · ≤200 → ULB (5) · 210–250 → transcendence
        def tier_for(level)
          return { min_uncap: 3, transcendence_stage: 0 } if level.nil?

          lvl = level.to_i
          return { min_uncap: 3, transcendence_stage: 0 } if lvl <= 100
          return { min_uncap: 4, transcendence_stage: 0 } if lvl <= 150
          return { min_uncap: 5, transcendence_stage: 0 } if lvl <= 200

          { min_uncap: 5, transcendence_stage: ((lvl - 200) / 10.0).ceil.clamp(1, 5) }
        end

        def entry(hash, slot, suffix: nil)
          prefix    = suffix ? "s#{slot}_#{suffix}" : "s#{slot}"
          en_prefix = suffix ? "ens#{slot}_#{suffix}" : "ens#{slot}"

          raw_name = hash["#{prefix}_name"]
          return nil if raw_name.blank?

          name = raw_name.gsub(/\{\{WeaponSkillMod\|[^}]+\}\}\s*/, "").gsub(/<!--.*?-->/, "").strip
          name = resolve_ifeq_name(name)

          description = hash["#{en_prefix}_desc"].presence || hash["#{prefix}_desc"]
          unlock_level = hash["#{prefix}_lvl"].presence&.to_i
          parsed = Granblue::Parsers::WeaponSkillParser.parse(name)
          tier = tier_for(unlock_level)

          modifier = parsed[:modifier]
          modifier = modifier.sub(ELEMENT_SUFFIX, "") if modifier

          size = size_from_description(description)
          size = "big_ii" if size == "big" && raw_name =~ /\bII\b/ && raw_name !~ /\bIII\b/
          size ||= parsed[:size]

          {
            suffix: suffix,
            name_en: name,
            name_jp: hash["jp#{prefix}_name"].presence,
            description_en: description,
            icon: hash["#{prefix}_icon"],
            unlock_level: unlock_level,
            min_uncap: tier[:min_uncap],
            transcendence_stage: tier[:transcendence_stage],
            main_hand_only: main_hand_only_description?(description),
            mc_only: description.to_s.match?(/\(mc only\)/i),
            modifier: modifier,
            size: size
          }
        end

        # Dark Opus `{{#ifeq:…|Majesty III|Majesty}}` names: both branches share the
        # modifier, so the ELSE (last) branch.
        def resolve_ifeq_name(name)
          return name if name.blank? || !name.include?("#ifeq")

          name.gsub(/\{\{\s*#ifeq:.*\|\s*([^|{}]+?)\s*\}\}/m, '\1').strip
        end

        # The size word of the skill's own text. Markup is not text: Metal Hand's
        # `<span class="text-small">Big boost…` is a big skill, and a `<!--…-->` editor
        # note or a `<ref>` citation can name a size the skill doesn't have. Templates stay
        # ({{tt|20% boost|'''Size:''' Big…}} is where Hollowsky's size lives).
        def size_from_description(description)
          return nil if description.blank?

          m = strip_markup(description).match(SIZE_KEYWORD) or return nil
          m[1].downcase
        end

        def strip_markup(text)
          text.gsub(/<!--.*?(?:-->|\z)/m, " ")
              .gsub(%r{<ref\b[^>]*/>}i, " ")
              .gsub(%r{<ref\b[^>]*>.*?(?:</ref>|\z)}im, " ")
              .gsub(/<[^>]+>/, " ")
        end

        # A later main-hand-only clause does not make an earlier always-on one main-hand-only.
        def main_hand_only_description?(description)
          text = description.to_s
          clauses = text.split(%r{<br\s*/?>}i)
          (clauses.length > 1 ? clauses.first : text).match?(/when main weapon/i)
        end
      end
    end
  end
end
