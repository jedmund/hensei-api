# frozen_string_literal: true

module WeaponSkills
  # A skill tier's own text, read from a weapon's wiki source. Pure: no database, no
  # network. The structure compiler (W6a) calls it to fill Version#description_*, and
  # VersionText::Backfill uses it to fill weapon_skill_versions.description_*.
  #
  # The English text follows the structural parse's rule for Skill#description_en
  # (`ensN_desc`, else `sN_desc`). The full `sN_desc` the description extractor reads
  # for row compilation is a separate thing (Rows::Description / full_description).
  module TierText
    module_function

    # One tier's text from a parsed field hash (the page's `|key=value` fields merged with
    # its series template's).
    #   slot:   1-based wiki slot (s1…s4)
    #   suffix: nil for the base tier, else "4s", "5s", "u1"… (the sN_<suffix>_name keys)
    # → { name:, en:, jp: }, or nil when the tier has no name.
    def from_wiki_hash(hash, slot, suffix = nil)
      prefix = suffix ? "s#{slot}_#{suffix}" : "s#{slot}"
      raw_name = hash["#{prefix}_name"]
      return nil if raw_name.blank?

      en = hash["#{suffix ? "ens#{slot}_#{suffix}" : "ens#{slot}"}_desc"].presence || hash["#{prefix}_desc"]
      { name: clean_name(raw_name), en: presence(en), jp: presence(hash["jp#{prefix}_desc"]) }
    end

    # A tier's name field as the structural parse reads it: {{WeaponSkillMod|…}} and HTML
    # comments removed, and Dark Opus `{{#ifeq:…|Majesty III|Majesty}}` names resolved to
    # their ELSE (last) branch (both branches share the modifier).
    def clean_name(raw_name)
      name = raw_name.gsub(/\{\{WeaponSkillMod\|[^}]+\}\}\s*/, "").gsub(/<!--.*?-->/, "").strip
      return name if name.blank? || !name.include?("#ifeq")

      name.gsub(/\{\{\s*#ifeq:.*\|\s*([^|{}]+?)\s*\}\}/m, '\1').strip
    end

    # Every tier of a slot in the structural parse's order (ascending unlock level), with
    # the ordinal it would give it.
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
    # skill name (Build::Structure::Expanded.rows: Multiplier annotation stripped). Key-slot
    # option rows carry key_type and are not a weapon's base tiers.
    # → { name => { en:, key_type: } }
    def from_expanded(html)
      return {} if html.blank?

      WeaponSkills::Build::Structure::Expanded.rows(html).to_h do |row|
        [row[:name], { en: presence(row[:description]), key_type: row[:key_type] }]
      end
    end

    # A field the line-based parser cut short (`|jps1_desc={{#switch:` continues on the
    # next lines, so only "{{" is kept) has unbalanced template braces: no usable text.
    def presence(value)
      text = value.to_s.strip.presence or return nil
      text.scan("{{").size == text.scan("}}").size ? text : nil
    end

    private_class_method :clean_name, :presence
  end
end
