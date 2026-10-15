# frozen_string_literal: true

module WeaponSkills
  module VersionText
    # Fills weapon_skill_versions.description_en/_jp with each tier's own text, read
    # offline from stored sources (weapon_sources through Wiki.offline). Never fetches.
    #
    # Where the English text comes from, in order:
    #   inline / key-determined pages:
    #     :tier          the slot's tier at the version's ordinal, when its name matches
    #     :tier_by_name  another tier of the same slot with the version's name
    #     :page_by_name  a tier of another slot with the version's name
    #     :expanded      the stored expansion's skill table, by name
    #   series-template pages: :expanded first, then the above.
    #   :fallback      none of those: today's Skill#description_en is copied, so the
    #                  version stops following later writes to the shared skill.
    # JP: the matched tier's jpsN_desc, else a tier with that name anywhere on the page,
    # else Skill#description_jp.
    #
    # Only versions whose columns are both NULL are touched, unless force: (curated text
    # from the overlay's `description` op is rewritten by the next curation sync anyway).
    class Backfill
      Structure = WeaponSkills::Build::Structure

      Result = Struct.new(:en_sources, :jp_sources, :fallbacks, :written, :weapon_errors, keyword_init: true) do
        def to_h = super.merge(fallbacks: fallbacks.size)
      end

      def self.run(...) = new(...).run

      def initialize(store: WeaponSkills::SourceStore::Database.new, force: false, dry_run: false, weapon_ids: nil)
        @store = store
        @force = force
        @dry_run = dry_run
        @weapon_ids = weapon_ids
      end

      def run
        @result = Result.new(en_sources: Hash.new(0), jp_sources: Hash.new(0), fallbacks: [], written: 0,
                             weapon_errors: [])
        Granblue::Parsers::Wiki.offline(store: @store) do
          versions_by_weapon.each { |granblue_id, versions| backfill_weapon(granblue_id, versions) }
        end
        @result
      end

      # Text for one version from already-loaded page data. Pure; the specs drive it.
      # page: { page_kind:, hash:, expanded: } (any may be nil)
      def self.resolve(version_position:, ordinal:, name:, page:, skill: nil)
        hash = page[:hash]
        expanded = page[:expanded] || {}
        match = nil
        if page[:page_kind] == "series_template" && (row = expanded[name]) && row[:en]
          match = [:expanded, { en: row[:en] }]
        end
        match ||= tier_match(hash, version_position + 1, ordinal, name) if hash
        match ||= [:expanded, { en: expanded[name][:en] }] if expanded[name]&.dig(:en)

        en_source, text = match || [:fallback, {}]
        en = text[:en] || skill&.description_en
        en_source = :fallback if text[:en].blank?

        jp = text[:jp] || (hash && TierText.jp_for_name(hash, name))
        jp_source = :wiki if jp
        jp ||= skill&.description_jp.presence
        jp_source ||= jp ? :fallback : :none

        { en: en, jp: jp, en_source: en_source, jp_source: jp_source }
      end

      def self.tier_match(hash, slot, ordinal, name)
        tiers = TierText.tiers(hash, slot)
        tier = tiers.find { |t| t[:ordinal] == ordinal && t[:name] == name }
        return [:tier, tier] if tier && tier[:en]

        tier = tiers.select { |t| t[:name] == name && t[:en] }.min_by { |t| (t[:ordinal] - ordinal).abs }
        return [:tier_by_name, tier] if tier

        (1..4).each do |other|
          next if other == slot

          tier = TierText.tiers(hash, other).find { |t| t[:name] == name && t[:en] }
          return [:page_by_name, tier] if tier
        end
        nil
      end

      private

      def versions_by_weapon
        scope = WeaponSkillVersion.joins(:weapon_skill).includes(:skill, :weapon_skill)
        scope = scope.where(description_en: nil, description_jp: nil) unless @force
        scope = scope.where(weapon_skills: { weapon_granblue_id: @weapon_ids }) if @weapon_ids
        scope.to_a.group_by { |v| v.weapon_skill.weapon_granblue_id }.sort.to_h
      end

      def backfill_weapon(granblue_id, versions)
        page = load_page(granblue_id)
        versions.sort_by { |v| [v.weapon_skill.position, v.ordinal] }.each do |v|
          text = self.class.resolve(version_position: v.weapon_skill.position, ordinal: v.ordinal,
                                    name: v.skill&.name_en, page: page, skill: v.skill)
          record(granblue_id, v, text, page)
          next if @dry_run

          v.update_columns(description_en: text[:en], description_jp: text[:jp])
          @result.written += 1
        end
      end

      def record(granblue_id, version, text, page)
        @result.en_sources[text[:en_source]] += 1
        @result.jp_sources[text[:jp_source]] += 1
        return unless text[:en_source] == :fallback

        @result.fallbacks << { weapon_granblue_id: granblue_id, position: version.weapon_skill.position,
                               ordinal: version.ordinal, skill: version.skill&.name_en,
                               page_kind: page[:page_kind] || "none" }
      end

      # The weapon's stored page: its page kind, parsed field hash (transclusions and the
      # series template followed, as the structure compiler does) and expanded skill table.
      def load_page(granblue_id)
        weapon = pick_weapon(granblue_id) or return {}
        raw = fetch("wiki_raw", weapon.wiki_en) or return {}

        expanded = fetch("expanded", weapon.wiki_en)
        { page_kind: raw.page_kind, hash: parse_hash(weapon, raw.body),
          expanded: expanded ? TierText.from_expanded(expanded.body) : {} }
      end

      # A few granblue_ids belong to two weapon rows; prefer the one with a stored page.
      def pick_weapon(granblue_id)
        weapons = Weapon.where(granblue_id: granblue_id).order(:id).to_a
        weapons.find { |w| w.wiki_en.present? && fetch("wiki_raw", w.wiki_en) } || weapons.first
      end

      # The field hash the tier text reads: the page that holds the skill fields
      # (Build::Structure.skill_source_text: a Mk II's base page, a character page's
      # "(Weapon)" page) with its series template's fields merged on top. A plain merge,
      # without the level defaults Structure::Wikitext.merge_template adds: those reorder
      # tiers, and this only needs each tier's text. nil when a page it needs isn't stored.
      def parse_hash(weapon, body)
        missing = []
        text = Structure.skill_source_text(weapon, body, @store, missing)
        raise WeaponSkills::SourceStore::SourceMissing.new("wiki_raw", missing.first) if missing.any?

        hash = Structure::Wikitext.fields(text)
        if hash[:template]
          key = "Template:#{hash[:template]}"
          template = Structure.followed_page(@store, key) or
            raise WeaponSkills::SourceStore::SourceMissing.new("transclusion", key)
          hash.merge!(Structure::Wikitext.fields(template))
        end
        hash
      rescue WeaponSkills::SourceStore::SourceMissing => e
        @result.weapon_errors << { weapon_granblue_id: weapon.granblue_id, error: e.message }
        nil
      end

      def fetch(kind, key)
        return nil if key.blank?

        @store.fetch(kind, key)
      rescue WeaponSkills::SourceStore::SourceMissing
        nil
      end
    end
  end
end
