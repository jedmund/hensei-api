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
        @leveled = Set.new
        (overlay.entries("effects") + overlay.entries("data")).each do |row|
          next unless row["weapon"]

          ref = key(row["weapon"], row["skill"], row["ordinal"])
          @curated[ref] << row["boost_type"]
          @leveled << ref if self.class.leveled_row?(row)
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

      # True when a curated row of the version changes with skill level (Concrio 30/32/35 at
      # SL10/15/20) or depends on it (Malus Essence's copy_skill_level condition).
      def leveled?(version)
        @leveled.include?(version_key(version))
      end

      LEVEL_KEYS = %w[sl1 sl10 sl15 sl20 sl25].freeze

      # A datum or effect (overlay entry or row attributes, string keys) that varies with
      # skill level: different per-level values, a formula coefficient, a weapon_skill_curve
      # scaling, or a skill-level condition.
      def self.leveled_row?(row)
        row.values_at(*LEVEL_KEYS).compact.map(&:to_f).uniq.size > 1 || !row["coefficient"].nil? ||
          row["scaling_kind"] == "weapon_skill_curve" ||
          row.dig("condition", "type").to_s.include?("skill_level")
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
