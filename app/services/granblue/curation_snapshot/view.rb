# frozen_string_literal: true

module Granblue
  class CurationSnapshot
    # What the curation overlay says about one version, for the row compiler
    # (WeaponSkills::Build::Rows; the interface is agreed on hensei-api #548). The
    # database-backed twin is WeaponSkills::Build::CurationView.
    #
    # `version` is a WeaponSkills::BuildResult::Version; it's matched on
    # [weapon_granblue_id, skill_name_en, ordinal], the overlay's version reference.
    class View
      EMPTY = Set.new.freeze

      def initialize(overlay)
        @curated = Hash.new { |h, k| h[k] = Set.new }
        @suppressed = {}
        @pinned = Set.new
        (overlay.entries("effects") + overlay.entries("data")).each do |row|
          @curated[key(row["weapon"], row["skill"], row["ordinal"])] << row["boost_type"] if row["weapon"]
        end
        overlay.entries("versions").each do |entry|
          ref = key(entry["weapon"], entry["skill"], entry["ordinal"])
          @suppressed[ref] = Array(entry["suppressed_boosts"]).to_set.freeze
          @pinned << ref if entry["modifier_override"].present?
        end
        @curated = @curated.transform_values(&:freeze)
      end

      # Boost types with a curated datum or effect row on the version.
      def curated_boost_types(version)
        @curated.fetch(version_key(version), EMPTY)
      end

      # The version's suppressed_boosts; "*" suppresses all extraction.
      def suppressed(version)
        @suppressed.fetch(version_key(version), EMPTY)
      end

      # True when the overlay sets the version's family (including "none").
      def modifier_pinned?(version)
        @pinned.include?(version_key(version))
      end

      private

      def version_key(version)
        key(version.weapon_granblue_id, version.skill_name_en, version.ordinal)
      end

      def key(weapon, skill, ordinal)
        [weapon.to_s, skill.to_s, ordinal.to_i]
      end
    end
  end
end
