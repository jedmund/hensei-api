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

    # Structural parse rebuilds slots/versions; series-template weapons are then
    # repaired via template expansion (network — their raw wikitext has no skill
    # text); finally the description extractor re-attributes frames and
    # regenerates the version-linked data/effects the rebuild destroyed
    # (preserving gameplay-notes kinds and manually-edited rows).
    def reparse_weapon
      saved = snapshot_manual_rows

      if template_only_wikitext?
        # Series-template weapons have no skill text in their raw wikitext — a raw
        # structural parse would garble their names and force repair to recreate
        # versions (cascading away version-linked curation). Repair matches by
        # name and is idempotent, so it runs alone.
        repair = Extractors::ExpandedWeaponSkillImporter.repair_weapon(@entity)
        raise WikiError, 'Template expansion failed' if repair == :expand_failed
      else
        Parsers::WeaponParser.new(granblue_id: @entity.granblue_id).persist_skills_from_wiki_raw
        # Weapons with inline template artifacts in their skill NAMES (e.g.
        # "Sephira Maxi-{{WeaponElement|...}}") need expansion to resolve them.
        repair = if garbled_versions.exists?
                   Extractors::ExpandedWeaponSkillImporter.repair_weapon(@entity, force: true)
                 else
                   :not_template
                 end
      end

      Extractors::WeaponSkillDescriptionExtractor.run(weapon: @entity)
      restored = restore_manual_rows(saved)
      { skills: @entity.weapon_skills.reload.count, template_repair: repair,
        manual_rows: { saved: saved.size, restored: restored } }
    end

    def template_only_wikitext?
      @entity.wiki_raw.to_s.include?('{{Weapon/Common/') && !@entity.wiki_raw.to_s.include?('s1_desc=')
    end

    def weapon_versions
      WeaponSkillVersion.joins(:weapon_skill)
                        .where(weapon_skills: { weapon_granblue_id: @entity.granblue_id })
    end

    def garbled_versions
      weapon_versions.joins(:skill).where('skills.name_en LIKE ?', '%{{%')
    end

    MANUAL_ROW_COLUMNS_EXCLUDED = %w[id weapon_skill_version_id created_at updated_at].freeze

    # Version-linked rows with manual curation die with their version when the
    # pipeline rebuilds slots. Snapshot them before, re-attach after — keyed by
    # the row's modifier, which is the owning skill's name.
    def snapshot_manual_rows
      [WeaponSkillDatum, WeaponSkillEffect].flat_map do |model|
        model.where(weapon_skill_version_id: weapon_versions.select(:id))
             .where.not(manually_edited_at: nil)
             .map { |row| { model: model, attrs: row.attributes.except(*MANUAL_ROW_COLUMNS_EXCLUDED) } }
      end
    end

    def restore_manual_rows(saved)
      versions_by_name = weapon_versions.includes(:skill).group_by { |v| v.skill&.name_en }
      saved.sum do |entry|
        targets = versions_by_name[entry[:attrs]['modifier']] || []
        targets.count do |version|
          scope = entry[:model].where(weapon_skill_version_id: version.id,
                                      boost_type: entry[:attrs]['boost_type'])
          scope = scope.where(scaling_kind: entry[:attrs]['scaling_kind']) if entry[:model] == WeaponSkillEffect
          # replace any regenerated (non-manual) counterpart with the curated row
          scope.where(manually_edited_at: nil).delete_all
          next false if scope.exists?

          entry[:model].create!(entry[:attrs].merge('weapon_skill_version_id' => version.id))
          true
        end
      end
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
