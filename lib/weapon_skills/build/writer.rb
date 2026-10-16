# frozen_string_literal: true

module WeaponSkills
  module Build
    # Writes one weapon's BuildResult to the database, upserting by identity so ids survive
    # rebuilds:
    #   slot     [weapon_granblue_id, position]
    #   version  [weapon_granblue_id, position, ordinal]
    #   row      the tables' version-scoped uniqueness: datum [boost_type, series, size],
    #            effect [boost_type, scaling_kind, condition]
    #
    # What it never touches:
    #   - curated rows (manually_edited_at set), or a generated row that would collide with one;
    #   - the overlay's columns on a version (*_override, suppressed_boosts, overrides_edited_at);
    #   - the shared Skill catalogue's text (a missing Skill is created by name).
    # A version or slot the build no longer produces is deleted, unless curated rows hang on
    # it or the overlay overrides it: then it's kept and counted in versions_kept. Runs in one
    # (nested) transaction.
    class Writer
      Report = Struct.new(:versions_created, :versions_updated, :versions_deleted, :versions_kept,
                          :slots_created, :slots_deleted, :rows_created, :rows_updated, :rows_deleted,
                          :rows_kept_curated, keyword_init: true) do
        def self.zero = new(**members.index_with(0))

        def merge!(other)
          members.each { |m| self[m] += other[m] }
          self
        end

        def changed? = (members - %i[versions_kept rows_kept_curated]).any? { |m| self[m].positive? }
      end

      VERSION_COLUMNS = %i[unlock_level min_uncap transcendence_stage icon skill_modifier skill_series skill_size
                           multiplier_frame main_hand_only mc_only scales_with_skill_level].freeze
      DESCRIPTION_COLUMNS = %i[description_en description_jp].freeze
      MODELS = { datum: WeaponSkillDatum, effect: WeaponSkillEffect }.freeze
      ROW_DEFAULTS = { provenance: nil }.freeze

      # context: accepted for symmetry with Build.for; the writer needs nothing from it.
      def self.call(result, context: nil) # rubocop:disable Lint/UnusedMethodArgument
        new(result).call
      end

      def initialize(result)
        @result = result
        @report = Report.zero
      end

      def call
        ActiveRecord::Base.transaction(requires_new: true) do
          slots = write_slots
          versions = write_versions(slots)
          write_rows(versions)
          delete_gone_versions(versions)
          delete_gone_slots
        end
        @report
      end

      private

      def gid = @result.weapon_granblue_id

      def existing_slots
        WeaponSkill.where(weapon_granblue_id: gid).index_by(&:position)
      end

      # → { position => WeaponSkill }
      def write_slots
        slots = existing_slots
        @result.slots.each do |slot|
          next if slots.key?(slot.position)

          slots[slot.position] = WeaponSkill.create!(weapon_granblue_id: gid, position: slot.position)
          @report.slots_created += 1
        end
        slots
      end

      # → { version identity => WeaponSkillVersion }
      def write_versions(slots)
        @result.versions.to_h do |built|
          slot = slots.fetch(built.position)
          record = slot.weapon_skill_versions.find_or_initialize_by(ordinal: built.ordinal)
          created = record.new_record?
          record.skill = skill_for(built)
          VERSION_COLUMNS.each { |column| record[column] = column_value(built, column) }
          DESCRIPTION_COLUMNS.each { |column| record[column] = built[column] if built[column].present? }
          if record.changed?
            # Derived classification can be a value the model's list lacks (Celestial skills
            # carry their own name); the build is the source of these columns.
            record.save!(validate: false)
            @report[created ? :versions_created : :versions_updated] += 1
          end
          [built.identity, record]
        end
      end

      def column_value(built, column)
        value = built[column]
        case column
        when :transcendence_stage then value || 0
        when :main_hand_only, :mc_only then value || false
        when :scales_with_skill_level then value.nil? || value
        else value
        end
      end

      def skill_for(built)
        Skill.find_or_create_by!(name_en: built.skill_name_en, skill_type: :weapon) do |skill|
          skill.name_jp = built.skill_name_jp
        end
      end

      def write_rows(versions)
        desired = @result.rows.group_by(&:version_identity)
        versions.each do |identity, record|
          MODELS.each do |kind, model|
            wanted = (desired[identity] || []).select { |row| row.kind == kind }
            write_rows_for(model, kind, record, wanted)
          end
        end
      end

      def write_rows_for(model, kind, version, wanted)
        existing = model.where(weapon_skill_version_id: version.id).to_a
        curated, generated = existing.partition(&:manually_edited_at)
        curated_keys = curated.to_set { |row| row_key(kind, row.attributes.symbolize_keys) }
        by_key = generated.index_by { |row| row_key(kind, row.attributes.symbolize_keys) }

        wanted.each do |row|
          # provenance is set only on fallback rows; nil clears a stale one
          attrs = ROW_DEFAULTS.merge(row.attributes).merge(weapon_skill_version_id: version.id)
          key = row_key(kind, attrs)
          if curated_keys.include?(key)
            @report.rows_kept_curated += 1
            next
          end

          record = by_key.delete(key)
          if record.nil?
            model.create!(attrs)
            @report.rows_created += 1
          else
            record.assign_attributes(attrs)
            next unless record.changed?

            record.save!
            @report.rows_updated += 1
          end
        end
        by_key.each_value(&:destroy!)
        @report.rows_deleted += by_key.size
      end

      def row_key(kind, attrs)
        if kind == :datum
          [attrs[:boost_type], attrs[:series], attrs[:size]]
        else
          [attrs[:boost_type], attrs[:scaling_kind], canonical(attrs[:condition] || {})]
        end
      end

      # Stored jsonb and built hashes differ in key type and order; compare them as sorted JSON.
      def canonical(value)
        sort = lambda do |v|
          case v
          when Hash then v.to_h { |k, x| [k.to_s, sort.call(x)] }.sort.to_h
          when Array then v.map(&sort)
          else v
          end
        end
        JSON.generate(sort.call(value))
      end

      def delete_gone_versions(kept)
        keep_ids = kept.values.map(&:id)
        WeaponSkillVersion.joins(:weapon_skill).where(weapon_skills: { weapon_granblue_id: gid })
                          .where.not(id: keep_ids).find_each do |version|
          if curated?(version)
            @report.versions_kept += 1
          else
            version.destroy!
            @report.versions_deleted += 1
          end
        end
      end

      def delete_gone_slots
        positions = @result.slots.map(&:position)
        WeaponSkill.where(weapon_granblue_id: gid).where.not(position: positions).find_each do |slot|
          next if slot.weapon_skill_versions.exists?

          slot.destroy!
          @report.slots_deleted += 1
        end
      end

      # Curated rows or overlay overrides mark a version as hand-maintained.
      def curated?(version)
        return true if version.overrides_edited_at.present?

        MODELS.values.any? do |model|
          model.where(weapon_skill_version_id: version.id).where.not(manually_edited_at: nil).exists?
        end
      end
    end
  end
end
