# frozen_string_literal: true

module CharacterSkills
  # A record of every character skill version's game icon, kept as one shared
  # `sources` row (kind icon_snapshot, PR 7b; it was data/character_skills/icons.json).
  # The builder falls back to it when a character has no game data, so a reparse from
  # wikitext alone keeps the icons that came from the game. An entry applies only when
  # its name_en matches the built version's name, so a reshaped wiki page can't move an
  # icon. The body is the JSON text as exported, so its sha256 (the build fingerprint's
  # input) is the old file's digest.
  #
  # Loaded once and kept while the row's sha256 stays the same: refresh! (which the build
  # fingerprint calls at the start of each run) reloads it when another process stored a new
  # snapshot, so a build and the fingerprint it records always use the same snapshot.
  module IconSnapshot
    KIND = 'icon_snapshot'
    KEY = 'character_skills'
    KEYS = %w[granblue_id style kind position ordinal name_en game_icon].freeze

    # Two stored versions share a snapshot key but disagree on name or icon.
    class ConflictError < StandardError; end

    # An export would drop more entries than MAX_REMOVED from the stored snapshot.
    class ShrinkError < StandardError; end

    # The most entries an export may drop from the stored snapshot. An entry is one ability or
    # support version, so one character is about ten; a reshaped wiki page or a renumbered slot
    # drops a few. Losing more means a failed build or wiped rows, and the snapshot is the only
    # copy of those icons, so the export keeps the stored one (max_removed: nil overrides).
    MAX_REMOVED = 20

    # Before slots carry their owner row (character_id), every slot belongs to
    # the base row (style_swap: false) for its granblue_id, so every entry is style 1.
    EXPORT_SQL_BY_GRANBLUE_ID = <<~SQL.squish.freeze
      SELECT DISTINCT owner.granblue_id, 1, s.kind, s.position, v.ordinal, v.name_en, v.game_icon
      FROM character_skill_versions v
      JOIN character_skills s ON s.id = v.character_skill_id
      JOIN characters owner ON owner.granblue_id = s.character_granblue_id AND owner.style_swap = false
      WHERE v.game_icon IS NOT NULL
      ORDER BY 1, 2, 3, 4, 5, 6, 7
    SQL

    # Slots owned by a character row: the style comes from that row.
    EXPORT_SQL_BY_CHARACTER_ID = <<~SQL.squish.freeze
      SELECT DISTINCT owner.granblue_id, CASE WHEN owner.style_swap THEN 2 ELSE 1 END, s.kind, s.position, v.ordinal,
                      v.name_en, v.game_icon
      FROM character_skill_versions v
      JOIN character_skills s ON s.id = v.character_skill_id
      JOIN characters owner ON owner.id = s.character_id
      WHERE v.game_icon IS NOT NULL
      ORDER BY 1, 2, 3, 4, 5, 6, 7
    SQL

    class << self
      # Stores every stored version that has a game_icon as the snapshot. Returns the entry count.
      # Raises ConflictError or ShrinkError, storing nothing, when the export is suspect.
      def export(max_removed: MAX_REMOVED)
        entries = export_rows
        check_conflicts!(entries)
        check_shrink!(entries, max_removed) if max_removed
        store(serialize(entries))
        entries.size
      end

      # Stores text (the snapshot's JSON, as exported) as the snapshot row. A changed snapshot
      # changes every character's fingerprint, so the stale build is queued (in
      # CHARACTER_SKILL_BUILD's mode), as for a changed status list.
      def store(text, fetched_at: nil)
        result = Source.put(nil, KIND, text, key: KEY, fetched_at: fetched_at)
        reset!
        CharacterSkills::StaleBuildJob.perform_later if result.changed? && CharacterSkills.build_mode != 'off'
        result
      end

      # The stored row's sha256 (the build fingerprint's input), or nil.
      def sha256
        Source.where(owner_type: nil, owner_id: nil, kind: KIND, key: KEY).pick(:sha256)
      end

      # { [granblue_id, style, kind, position, ordinal] => { name_en:, game_icon: } },
      # memoized (see refresh!). No row is an empty index.
      def load
        refresh! unless @loaded
        @load
      end

      # Reloads the index when the stored row's sha256 differs from the loaded one. → the
      # loaded snapshot's sha256, or nil when none is stored.
      def refresh!
        return @loaded_sha256 if @loaded && sha256 == @loaded_sha256

        row = Source.fetch(nil, KIND, key: KEY)
        @load = build_index(row&.body)
        @slot_index = nil
        @loaded = true
        @loaded_sha256 = row&.sha256
      end

      # The entry for a version, or nil.
      def lookup(granblue_id:, style:, kind:, position:, ordinal:)
        load[[granblue_id.to_s, style.to_i, kind.to_s, position.to_i, ordinal.to_i]]
      end

      # The snapshot icon for a built version, or nil. The entry at the exact key
      # wins when it names the same ability. Otherwise (a rebuild renumbered the
      # slot's versions) the slot's entries with that name decide, but only when
      # they all agree on one icon. key: { granblue_id:, style:, kind:, position:, ordinal: }.
      def icon_for(key, name_en:)
        return if name_en.blank?

        exact = lookup(**key)
        return exact[:game_icon].presence if exact && exact[:name_en] == name_en

        slot = slot_index[[key[:granblue_id].to_s, key[:style].to_i, key[:kind].to_s, key[:position].to_i]] || []
        icons = slot.filter_map { |entry| entry[:game_icon].presence if entry[:name_en] == name_en }.uniq
        icons.first if icons.one?
      end

      def reset!
        @load = nil
        @slot_index = nil
        @loaded = false
        @loaded_sha256 = nil
      end

      private

      # { [granblue_id, style, kind, position] => [{ name_en:, game_icon: }, ...] }
      def slot_index
        @slot_index ||= load.each_with_object({}) do |(key, entry), index|
          (index[key.first(4)] ||= []) << entry
        end
      end

      def build_index(text)
        return {} if text.blank?

        JSON.parse(text).to_h { |entry| [index_key(entry), { name_en: entry['name_en'], game_icon: entry['game_icon'] }] }
      end

      # One entry per (granblue_id, style, kind, position, ordinal). Older parses
      # left duplicate versions with the same ordinal, name and icon; DISTINCT
      # collapses them.
      def export_rows
        sql = owner_key? ? EXPORT_SQL_BY_CHARACTER_ID : EXPORT_SQL_BY_GRANBLUE_ID
        rows = ActiveRecord::Base.connection.select_rows(sql)
        rows.map do |row|
          KEYS.zip(row).to_h.merge('style' => row[1].to_i, 'position' => row[3].to_i, 'ordinal' => row[4].to_i)
        end
      end

      def check_conflicts!(entries)
        conflicts = entries.group_by { |entry| entry.values_at(*KEYS.first(5)) }.select { |_, group| group.size > 1 }
        return if conflicts.empty?

        sample = conflicts.first(5).map { |key, group| "#{key.join('/')}: #{group.map { |e| e.values_at('name_en', 'game_icon') }}" }
        raise ConflictError, "#{conflicts.size} snapshot keys have conflicting versions, e.g. #{sample.join('; ')}"
      end

      def check_shrink!(entries, max_removed)
        stored = build_index(Source.fetch(nil, KIND, key: KEY)&.body)
        removed = (stored.keys - entries.map { |entry| index_key(entry) }).size
        return if removed <= max_removed

        raise ShrinkError, "the export would remove #{removed} of #{stored.size} snapshot entries (limit #{max_removed})"
      end

      def index_key(entry)
        [entry['granblue_id'].to_s, entry['style'].to_i, entry['kind'].to_s, entry['position'].to_i, entry['ordinal'].to_i]
      end

      def owner_key?
        CharacterSkill.column_names.include?('character_id')
      end

      def serialize(entries)
        lines = entries.map { |entry| "  #{JSON.generate(entry)}" }
        "[\n#{lines.join(",\n")}\n]\n"
      end
    end
  end
end
