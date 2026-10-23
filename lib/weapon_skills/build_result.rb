# frozen_string_literal: true

module WeaponSkills
  # What the build produces for one weapon, before anything is written. Pure values:
  # the structure compiler fills slots and versions, the row compiler fills rows, and the
  # writer upserts them by identity (ids survive rebuilds).
  #
  # Identities:
  #   version → [weapon_granblue_id, position, ordinal]
  #   row     → [version identity, kind, boost_type, condition]   (kind: :datum | :effect)
  class BuildResult
    # A skill slot on the weapon (weapon_skills row).
    Slot = Struct.new(:weapon_granblue_id, :position, keyword_init: true) do
      def identity = [weapon_granblue_id, position]
    end

    # One tier of a slot (weapon_skill_versions row). Derived fields only: overrides
    # live in the curation overlay, never here.
    Version = Struct.new(
      :weapon_granblue_id, :position, :ordinal,
      :skill_name_en, :skill_name_jp, :description_en, :description_jp,
      :unlock_level, :min_uncap, :transcendence_stage,
      :skill_modifier, :skill_series, :skill_size, :multiplier_frame,
      :icon, :main_hand_only, :mc_only, :scales_with_skill_level,
      keyword_init: true
    ) do
      def identity = [weapon_granblue_id, position, ordinal]
    end

    # A generated version-linked row. `kind` picks the table (weapon_skill_data or
    # weapon_skill_effects); `attributes` holds that table's columns, excluding ids,
    # timestamps and curation stamps. provenance is present only on a datum copied from a
    # fallback curve ("fallback:<modifier>/<series>"); the writer clears it elsewhere.
    ROW_KINDS = %i[datum effect].freeze
    Row = Struct.new(:version_identity, :kind, :boost_type, :condition, :attributes, keyword_init: true) do
      def identity = [version_identity, kind, boost_type, condition || {}]
    end

    attr_reader :weapon_granblue_id, :slots, :versions, :rows, :warnings

    def initialize(weapon_granblue_id:, slots: [], versions: [], rows: [], warnings: [])
      @weapon_granblue_id = weapon_granblue_id
      @slots = slots
      @versions = versions
      @rows = rows
      @warnings = warnings
    end

    # Duplicate identities mean the compiler produced two answers for one thing.
    def validate!
      { slots: slots, versions: versions, rows: rows }.each do |name, items|
        dupes = items.group_by(&:identity).select { |_, group| group.size > 1 }.keys
        raise ArgumentError, "duplicate #{name} identities: #{dupes.first(3).inspect}" if dupes.any?
      end
      bad = rows.reject { |r| ROW_KINDS.include?(r.kind) }
      raise ArgumentError, "unknown row kinds: #{bad.map(&:kind).uniq.inspect}" if bad.any?

      self
    end
  end
end
