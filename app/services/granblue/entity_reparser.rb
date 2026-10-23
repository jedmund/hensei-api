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

    LOCK_WAIT = 5.seconds

    def initialize(entity, refetch: false)
      @entity = entity
      @refetch = refetch
    end

    def reparse
      # The fetch saves wiki_raw, which would also queue CharacterSkills::BuildJob or
      # SummonAuras::BuildJob; this reparse builds the entity itself.
      Character.without_skill_build { Summon.without_aura_build { WikiFetcher.new.fetch_and_store(@entity) } } if @refetch

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
    # Raises MissingWikiRawError when the weapon's page isn't stored (WeaponSource; a build
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

    # The build reads the weapon's page from the stored sources, by wiki_en.
    def stored_page?
      return false if @entity.wiki_en.blank?

      WeaponSkills::SourceStore::Database.new.fetch('wiki_raw', @entity.wiki_en)
      true
    rescue WeaponSkills::SourceStore::SourceMissing
      false
    end

    # Summons go through the summon-aura build (SummonAuras::Build::Runner in write mode, for
    # this summon only, even when it isn't stale): its stored wiki_raw in, its auras upserted by
    # natural key, so ids survive. → { auras:, built:, counts: }. Re-raises a build failure, and
    # raises MissingWikiRawError when the build was held back (it made no auras, so the existing
    # ones were kept) rather than reporting success.
    def reparse_summon
      log = StringIO.new
      summary = SummonAuras::Build::Runner.new(mode: 'write', ids: [@entity.granblue_id], all: true, io: log).call
      raise summary.errors.first.last if summary.errors.any?
      raise MissingWikiRawError, log.string.lines.first.to_s.strip.sub(/\A\S+ /, '') if summary.built.zero?

      { auras: @entity.auras.reload.count, built: summary.built, counts: summary.counts.to_h.except(:changes) }
    end

    # Characters go through the character-skill build (CharacterSkills::Build::Runner in write
    # mode, for this row only, even when it isn't stale): the row's stored sources in, its skills
    # upserted by natural key, so ids survive and nothing the sources still make is lost.
    # → { skills:, built:, counts: } (counts: the writer's report). Re-raises a build failure, and
    # raises MissingWikiRawError when the build was held back (it made no skills, so the
    # existing ones were kept) rather than reporting success. Waits up to LOCK_WAIT for a running
    # build of the character (CharacterSkills::BuildLock), then raises BuildLock::Busy.
    def reparse_character
      log = StringIO.new
      summary = nil
      locked = ::CharacterSkills::BuildLock.character(@entity.id, wait: LOCK_WAIT) do
        summary = ::CharacterSkills::Build::Runner.new(mode: 'write', characters: [@entity], all: true, io: log).call
      end
      raise ::CharacterSkills::BuildLock::Busy, ::CharacterSkills::Refresh::BUSY_MESSAGE unless locked
      raise summary.errors.first.last if summary.errors.any?
      raise MissingWikiRawError, log.string.lines.first.to_s.strip.sub(/\A\S+ /, '') if summary.built.zero?

      { skills: @entity.character_skills.count, built: summary.built, counts: summary.counts.to_h }
    end
  end
end
