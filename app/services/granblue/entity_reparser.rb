# frozen_string_literal: true

module Granblue
  # Re-parses one entity's stored wikitext into its structured skill/aura rows.
  # This is the safe single-entity counterpart of the bulk parse rakes: the
  # weapon path runs the FULL pipeline (structural parse, then description
  # extraction with family backfill), so description-derived data/effects are
  # rebuilt rather than lost (the bulk `force=true` landmine).
  class EntityReparser
    class MissingWikiRawError < StandardError; end

    ELEMENT_WORD = { 1 => 'wind', 2 => 'fire', 3 => 'water', 4 => 'earth', 5 => 'dark', 6 => 'light' }.freeze
    AURA_COLUMNS = %w[target element value condition description_en].freeze

    def initialize(entity, refetch: false)
      @entity = entity
      @refetch = refetch
    end

    def reparse
      WikiFetcher.new.fetch_and_store(@entity) if @refetch
      raise MissingWikiRawError, 'No stored wikitext — fetch the wiki page first' if @entity.wiki_raw.blank?

      case @entity
      when Weapon then reparse_weapon
      when Summon then reparse_summon
      when Character then reparse_character
      else raise ArgumentError, "Unsupported entity #{@entity.class}"
      end
    end

    private

    # Structural parse rebuilds slots/versions; the description extractor then
    # re-attributes frames and regenerates the version-linked data/effects the
    # rebuild destroyed (preserving gameplay-notes kinds).
    def reparse_weapon
      Parsers::WeaponParser.new(granblue_id: @entity.granblue_id).persist_skills_from_wiki_raw
      Extractors::WeaponSkillDescriptionExtractor.run(weapon: @entity)
      { skills: @entity.weapon_skills.reload.count }
    end

    # Extract aura rows from the wikitext, upsert them, and prune this summon's
    # rows that the fresh parse no longer produces.
    def reparse_summon
      records = Extractors::SummonAuraExtractor.new.extract(
        @entity.wiki_raw,
        granblue_id: @entity.granblue_id,
        series: @entity.summon_series&.slug,
        element: ELEMENT_WORD[@entity.element]
      ).map { |r| r.transform_keys(&:to_s) }

      keys = records.to_set { |r| r.values_at('slot', 'uncap_level', 'transcendence_stage') }
      records.each do |r|
        aura = SummonAura.find_or_initialize_by(
          summon_granblue_id: @entity.granblue_id, slot: r['slot'],
          uncap_level: r['uncap_level'], transcendence_stage: r['transcendence_stage']
        )
        AURA_COLUMNS.each { |c| aura[c] = r[c] }
        aura.save!
      end
      SummonAura.where(summon_granblue_id: @entity.granblue_id)
                .reject { |a| keys.include?([a.slot, a.uncap_level, a.transcendence_stage]) }
                .each(&:destroy)
      { auras: records.size }
    end

    def reparse_character
      status_lookup = Parsers::CharacterSkillParser.build_status_lookup
      Parsers::CharacterSkillParser.new(@entity, status_lookup: status_lookup).parse(persist: true)
      { skills: CharacterSkill.where(character_granblue_id: @entity.granblue_id).count }
    end
  end
end
