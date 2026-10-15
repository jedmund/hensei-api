# frozen_string_literal: true

module WeaponSkills
  # A skill tier's own text, read from a weapon's wiki source. Pure: no database, no
  # network. The structure compiler (W6a) calls it to fill Version#description_*, and
  # VersionText::Backfill uses it to fill weapon_skill_versions.description_*.
  #
  # The English text follows the rule WeaponParser stores in Skill#description_en
  # (`ensN_desc`, else `sN_desc`). The full `sN_desc` the description extractor reads
  # for row compilation is a separate thing (Rows::Description / full_description).
  module TierText
    module_function

    # One tier's text from a parsed field hash (WeaponParser#parse_string output, the
    # page merged with its series template).
    #   slot:   1-based wiki slot (s1…s4)
    #   suffix: nil for the base tier, else "4s", "5s", "u1"… as in
    #           WeaponParser#discover_skill_versions
    # → { name:, en:, jp: }, or nil when the tier has no name.
    def from_wiki_hash(hash, slot, suffix = nil)
      entry = parser.send(:build_skill_entry, hash, slot, suffix: suffix) or return nil

      prefix = suffix ? "s#{slot}_#{suffix}" : "s#{slot}"
      { name: entry[:name_en], en: presence(entry[:description_en]), jp: presence(hash["jp#{prefix}_desc"]) }
    end

    # Every tier of a slot in the parser's order (ascending unlock level), with the
    # ordinal the parser would give it.
    # → [{ ordinal:, suffix:, name:, en:, jp:, unlock_level: }]
    def tiers(hash, slot)
      suffixes = []
      suffixes << nil if presence(hash["s#{slot}_name"])
      hash.each_key do |key|
        next unless key.to_s =~ /\As#{slot}_(\d+s|u\d+)_name\z/ && presence(hash[key])

        suffixes << Regexp.last_match(1)
      end

      found = suffixes.uniq.filter_map do |suffix|
        text = from_wiki_hash(hash, slot, suffix) or next
        level = presence(hash["#{suffix ? "s#{slot}_#{suffix}" : "s#{slot}"}_lvl"])&.to_i
        text.merge(suffix: suffix, unlock_level: level)
      end
      found.sort_by { |t| t[:unlock_level] || 0 }.each_with_index.map { |t, i| t.merge(ordinal: i) }
    end

    # The Japanese text of the tier named `name` anywhere on the page (series-template
    # pages carry jpsN_desc next to sN_name even when the English text is only in the
    # expansion). nil when no tier has that name or it has no JP text.
    def jp_for_name(hash, name)
      hash.each_key do |key|
        next unless key.to_s =~ /\As(\d)(?:_(\d+s|u\d+))?_name\z/

        slot = Regexp.last_match(1).to_i
        suffix = Regexp.last_match(2)
        text = from_wiki_hash(hash, slot, suffix)
        return text[:jp] if text && text[:name] == name && text[:jp]
      end
      nil
    end

    # The expanded "Weapon Skills" table of a series-template page, keyed by the cleaned
    # skill name (same row parsing as ExpandedWeaponSkillImporter: Multiplier annotation
    # stripped). Key-slot option rows carry key_type and are not a weapon's base tiers.
    # → { name => { en:, key_type: } }
    def from_expanded(html)
      return {} if html.blank?

      Granblue::Extractors::ExpandedWeaponSkillImporter.send(:parse_skills, html).to_h do |row|
        [row[:name], { en: presence(row[:description]), key_type: row[:key_type] }]
      end
    end

    # WeaponParser's tier builder is pure over the hash; an allocated parser skips the
    # weapon lookup its constructor does.
    def parser
      @parser ||= Granblue::Parsers::WeaponParser.allocate
    end

    # A field the line-based parser cut short (`|jps1_desc={{#switch:` continues on the
    # next lines, so only "{{" is kept) has unbalanced template braces: no usable text.
    def presence(value)
      text = value.to_s.strip.presence or return nil
      text.scan("{{").size == text.scan("}}").size ? text : nil
    end

    private_class_method :parser, :presence
  end
end
