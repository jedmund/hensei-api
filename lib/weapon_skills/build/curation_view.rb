# frozen_string_literal: true

module WeaponSkills
  module Build
    # What curation says about a version's rows, as the row compiler needs it. Agreed with
    # W7 (#546/#548); the overlay-backed view implements the same duck type:
    #
    #   curated_boost_types(version) → frozen Set[String]  boost types with a curated datum or
    #                                                      effect row on the version
    #   suppressed(version)          → frozen Set[String]  suppressed_boosts; "*" = suppress
    #                                                      all extraction
    #   modifier_pinned?(version)    → Boolean             the version has a modifier override
    #                                                      (including "none"); don't backfill a
    #                                                      family from the skill name
    #
    # `version` is a BuildResult::Version. This implementation is backed by the database,
    # exactly like today's extractor: version-linked rows with manually_edited_at set, plus
    # the version's suppressed_boosts and modifier_override. It loads everything up front.
    class CurationView
      EMPTY = Set.new.freeze

      Entry = Struct.new(:curated, :suppressed, :pinned, keyword_init: true)

      # weapon_granblue_ids: limit the load to these weapons (nil = all).
      def self.from_database(weapon_granblue_ids: nil)
        scope = WeaponSkillVersion.joins(:weapon_skill, :skill)
        scope = scope.where(weapon_skills: { weapon_granblue_id: weapon_granblue_ids }) if weapon_granblue_ids
        rows = scope.pluck("weapon_skill_versions.id", "weapon_skills.weapon_granblue_id", "weapon_skills.position",
                           "weapon_skill_versions.ordinal", "skills.name_en",
                           "weapon_skill_versions.suppressed_boosts", "weapon_skill_versions.modifier_override")
        ids = rows.map(&:first)
        curated = Hash.new { |h, k| h[k] = Set.new }
        [WeaponSkillDatum, WeaponSkillEffect].each do |model|
          model.where(weapon_skill_version_id: ids).where.not(manually_edited_at: nil)
               .pluck(:weapon_skill_version_id, :boost_type).each { |id, boost| curated[id] << boost }
        end

        entries = rows.to_h do |id, *identity, suppressed, override|
          weapon, position, ordinal, name = identity
          entry = Entry.new(curated: (curated.key?(id) ? curated[id] : EMPTY).dup.freeze,
                            suppressed: Array(suppressed).to_set.freeze,
                            pinned: override.present?)
          [[weapon.to_s, position.to_i, ordinal.to_i, name.to_s], entry]
        end
        new(entries)
      end

      # entries: { [weapon_granblue_id, position, ordinal, skill_name_en] => Entry }
      def initialize(entries = {})
        @entries = entries
        @by_name = entries.group_by { |(weapon, _, ordinal, name), _| [weapon, name, ordinal] }
                          .transform_values { |pairs| pairs.map(&:last) }
      end

      def curated_boost_types(version) = entry(version)&.curated || EMPTY
      def suppressed(version) = entry(version)&.suppressed || EMPTY
      def modifier_pinned?(version) = entry(version)&.pinned || false

      private

      def entry(version)
        weapon = version.weapon_granblue_id.to_s
        name = version.skill_name_en.to_s
        if version.position
          found = @entries[[weapon, version.position.to_i, version.ordinal.to_i, name]]
          return found if found
        end
        candidates = @by_name[[weapon, name, version.ordinal.to_i]]
        candidates&.size == 1 ? candidates.first : nil
      end
    end
  end
end
