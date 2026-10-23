# frozen_string_literal: true

module CharacterSkills
  module Build
    # What a set of characters' skill rows hold, without ids or timestamps: per character,
    # { [kind, position, ordinal] => entry }, where an entry is the version's build-owned
    # columns plus
    #   "slot_game_action_id"  the slot's game_action_id;
    #   "effects"              the effects' build-owned columns, by ordinal;
    #   "links"                [relation, "kind:position:ordinal" of the other end], sorted;
    #   "duplicates"           how many other rows share this key (left by older builds), when any.
    # The runner captures one before and one after a build; Diff compares them.
    class Snapshot
      def self.capture(character_ids)
        new.capture(character_ids)
      end

      def capture(character_ids)
        ids = Array(character_ids).uniq
        return {} if ids.empty?

        @links = nil

        slots = CharacterSkill.where(character_id: ids).pluck(:id, :character_id, :kind, :position, :game_action_id)
                              .index_by(&:first)
        versions = load_versions(slots.keys)
        effects = load_effects(versions.keys)
        key_by_version = versions.transform_values { |row| version_key(slots, row) }

        snapshot = ids.index_with { {} }
        versions.each do |version_id, row|
          slot = slots.fetch(row[:character_skill_id])
          entries = snapshot[slot[1]]
          key = key_by_version[version_id]
          if entries.key?(key)
            entries[key]["duplicates"] = entries[key].fetch("duplicates", 0) + 1
            next
          end

          entries[key] = row[:columns].merge(
            "slot_game_action_id" => slot[4],
            "effects" => effects.fetch(version_id, []).sort_by { |effect| effect["ordinal"].to_i },
            "links" => links_from(version_id, key_by_version)
          )
        end
        snapshot
      end

      private

      def load_versions(slot_ids)
        columns = Writer.version_columns
        CharacterSkillVersion.where(character_skill_id: slot_ids).order(:created_at, :id)
                             .pluck(:id, :character_skill_id, *columns)
                             .to_h { |id, slot_id, *values| [id, { character_skill_id: slot_id, columns: columns.zip(values).to_h }] }
      end

      def load_effects(version_ids)
        columns = Writer.effect_columns
        SkillEffect.where(character_skill_version_id: version_ids).order(:created_at, :id)
                   .pluck(:character_skill_version_id, *columns)
                   .group_by(&:first)
                   .transform_values { |rows| rows.map { |_, *values| columns.zip(values).to_h } }
      end

      def links_from(version_id, key_by_version)
        @links ||= CharacterSkillVersionLink.where(from_version_id: key_by_version.keys)
                                            .pluck(:from_version_id, :to_version_id, :relation).group_by(&:first)
        @links.fetch(version_id, []).map { |_, to_id, relation| [relation, Diff.key_label(key_by_version[to_id])] }.sort
      end

      def version_key(slots, row)
        _, _, kind, position = slots.fetch(row[:character_skill_id])
        [kind, position, row[:columns]["ordinal"]]
      end
    end
  end
end
