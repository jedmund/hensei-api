# frozen_string_literal: true

module CharacterSkills
  module Build
    # Writes one character's built graph (Granblue::Parsers::CharacterSkillParser#graph) to the
    # database, upserting by natural key (contract C2) so ids survive rebuilds:
    #   slot     (character_id, kind, position)
    #   version  (character_skill_id, ordinal)
    #   effect   (character_skill_version_id, ordinal)
    #   link     (from_version_id, to_version_id, relation), both ends resolved through the
    #            graph's version keys to the versions written here
    # Every build-owned column is assigned, a missing one as the column default, so a value the
    # build stops producing is cleared; a row is saved only when a column changed, so
    # updated_at means something.
    #
    # Rows the build no longer makes are deleted: versions, slots, effects and links. Nothing
    # outside references them (no curation yet; mentions are by name, parties by slot position).
    # When curation arrives, follow WeaponSkills::Build::Writer's "kept" rule (curated rows and
    # overrides keep their version). Older builds left duplicate ordinals; the oldest row keeps
    # the key and the rest are deleted. Runs in one (nested) transaction.
    class Writer
      Report = Struct.new(:slots_created, :slots_updated, :slots_deleted,
                          :versions_created, :versions_updated, :versions_deleted,
                          :effects_created, :effects_updated, :effects_deleted,
                          :links_created, :links_deleted, keyword_init: true) do
        def self.zero = new(**members.index_with(0))

        def merge!(other)
          members.each { |m| self[m] += other[m] }
          self
        end

        def changed? = to_h.values.any?(&:positive?)
      end

      BOOKKEEPING = %w[id created_at updated_at].freeze

      # Build-owned columns: everything but ids, the parent key and timestamps. Read lazily,
      # so loading the class doesn't need a database.
      def self.version_columns = CharacterSkillVersion.column_names - BOOKKEEPING - %w[character_skill_id]
      def self.effect_columns = SkillEffect.column_names - BOOKKEEPING - %w[character_skill_version_id]

      def self.call(character, graph)
        new(character, graph).call
      end

      # Icon stems on versions this write created or whose game_icon it changed (the icon job's input).
      attr_reader :icon_stems

      def initialize(character, graph)
        @character = character
        @graph = graph
        @report = Report.zero
        @icon_stems = Set.new
      end

      def call
        ActiveRecord::Base.transaction(requires_new: true) do
          slots = write_slots
          versions = write_versions(slots)
          write_links(versions)
          delete_gone_versions(versions.values)
          delete_gone_slots(slots.values.map(&:first))
        end
        @report
      end

      private

      # → { graph slot key => [CharacterSkill, slot hash] }
      def write_slots
        existing = CharacterSkill.where(character_id: @character.id).index_by { |slot| [slot.kind, slot.position] }
        @graph[:slots].to_h do |slot_hash|
          attrs = slot_hash[:attrs]
          record = existing[[attrs[:kind].to_s, attrs[:position]]] ||
                   CharacterSkill.new(character: @character, kind: attrs[:kind], position: attrs[:position])
          record.character_granblue_id = @character.granblue_id
          record.game_action_id = attrs[:game_action_id]
          save_counting(record, :slots)
          [slot_hash[:key], [record, slot_hash]]
        end
      end

      # → { graph version key => CharacterSkillVersion }
      def write_versions(slots)
        existing = CharacterSkillVersion.where(character_skill_id: slots.values.map { |slot, _| slot.id })
                                        .order(:created_at, :id).group_by(&:character_skill_id)
        slots.values.each_with_object({}) do |(slot, slot_hash), written|
          by_ordinal = first_by(existing.fetch(slot.id, []), &:ordinal)
          slot_hash[:versions].each do |version_hash|
            attrs = version_hash[:attrs]
            record = by_ordinal.delete(attrs[:ordinal]) || CharacterSkillVersion.new(character_skill: slot)
            assign(record, self.class.version_columns, attrs)
            created = record.new_record?
            save_counting(record, :versions)
            @icon_stems << record.game_icon if record.game_icon.present? && (created || record.saved_change_to_game_icon?)
            write_effects(record, version_hash[:effects])
            written[version_hash[:key]] = record
          end
        end
      end

      def write_effects(version, effects)
        existing = SkillEffect.where(character_skill_version_id: version.id).order(:created_at, :id).to_a
        by_ordinal = first_by(existing, &:ordinal)
        kept = effects.map do |effect_hash|
          record = by_ordinal.delete(effect_hash[:ordinal]) || SkillEffect.new(character_skill_version: version)
          assign(record, self.class.effect_columns, effect_hash)
          save_counting(record, :effects)
          record
        end
        gone = existing - kept
        gone.each(&:destroy!)
        @report.effects_deleted += gone.size
      end

      def write_links(versions)
        desired = @graph[:links].filter_map do |link|
          from = versions[link[:from_version_key]]
          to = versions[link[:to_version_key]]
          [from.id, to.id, link[:relation].to_s] if from && to
        end.uniq
        existing = CharacterSkillVersionLink.joins(from_version: :character_skill)
                                            .where(character_skills: { character_id: @character.id })
                                            .index_by { |link| [link.from_version_id, link.to_version_id, link.relation] }
        (desired - existing.keys).each do |from_id, to_id, relation|
          CharacterSkillVersionLink.create!(from_version_id: from_id, to_version_id: to_id, relation: relation)
          @report.links_created += 1
        end
        gone = existing.except(*desired).values
        gone.each(&:destroy!)
        @report.links_deleted += gone.size
      end

      # Versions the graph no longer makes, and duplicate-ordinal leftovers. Their links went
      # in write_links (no desired link touches them); their effects go with them.
      def delete_gone_versions(kept)
        CharacterSkillVersion.joins(:character_skill).where(character_skills: { character_id: @character.id })
                             .where.not(id: kept.map(&:id)).find_each do |version|
          @report.effects_deleted += version.skill_effects.count
          version.destroy!
          @report.versions_deleted += 1
        end
      end

      def delete_gone_slots(kept)
        CharacterSkill.where(character_id: @character.id).where.not(id: kept.map(&:id)).find_each do |slot|
          slot.destroy!
          @report.slots_deleted += 1
        end
      end

      # A built hash's value for each column, or the column's default when the build left it
      # out (the Builder compacts nils away).
      def assign(record, columns, attrs)
        defaults = record.class.column_defaults
        columns.each do |column|
          key = column.to_sym
          record[column] = attrs.key?(key) ? attrs[key] : defaults[column].deep_dup
        end
      end

      def save_counting(record, table)
        if record.new_record?
          record.save!
          @report[:"#{table}_created"] += 1
        elsif record.changed?
          record.save!
          @report[:"#{table}_updated"] += 1
        end
      end

      # The first record per key; records are ordered oldest first, so later duplicates are
      # left out (and deleted as gone).
      def first_by(records)
        records.each_with_object({}) { |record, index| index[yield(record)] ||= record }
      end
    end
  end
end
