# frozen_string_literal: true

module Granblue
  # Re-parses one entity's stored wiki source into its structured skill/aura rows.
  #
  # Weapons go through the weapon-skill build (WeaponSkills::Build::Runner in write mode,
  # for this weapon only): its stored sources and the curation overlay in, its slots,
  # versions and generated rows out, then the overlay sync and the key effects. Curated
  # rows and overrides survive, because the writer never touches them. refetch: true first
  # refreshes the weapon's stored sources from the wiki (WikiFetcher → SourceStore::Fetcher).
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

      case @entity
      when Weapon then reparse_weapon
      when Summon then require_wiki_raw! && reparse_summon
      when Character then require_wiki_raw! && reparse_character
      else raise ArgumentError, "Unsupported entity #{@entity.class}"
      end
    end

    private

    def require_wiki_raw!
      raise MissingWikiRawError, 'No stored wikitext — fetch the wiki page first' if @entity.wiki_raw.blank?

      true
    end

    # → { skills:, built:, warnings:, counts: } (counts: the writer's report).
    # Raises MissingWikiRawError when the weapon's page isn't in weapon_sources (a build
    # without it would delete the weapon's generated skills), and re-raises a build failure.
    def reparse_weapon
      unless stored_page?
        raise MissingWikiRawError, 'No stored wiki source for this weapon — fetch the wiki page first'
      end

      log = StringIO.new
      summary = WeaponSkills::Build::Runner.new(mode: 'write', ids: [@entity.granblue_id], all: true, io: log).call
      raise summary.errors.first.last if summary.errors.any?
      raise MissingWikiRawError, log.string.lines.first.to_s.strip if summary.built.zero?

      { skills: @entity.weapon_skills.reload.count, built: summary.built, warnings: summary.warnings,
        counts: summary.counts.to_h }
    end

    # The build reads the weapon's page from weapon_sources, by wiki_en.
    def stored_page?
      return false if @entity.wiki_en.blank?

      WeaponSkills::SourceStore::Database.new.fetch('wiki_raw', @entity.wiki_en)
      true
    rescue WeaponSkills::SourceStore::SourceMissing
      false
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
