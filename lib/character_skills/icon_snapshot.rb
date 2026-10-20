# frozen_string_literal: true

module CharacterSkills
  # A committed, read-only record of every character skill version's game icon
  # (data/character_skills/icons.json). The builder falls back to it when a
  # character has no game data, so a reparse from wikitext alone keeps the icons
  # that came from the game. An entry applies only when its name_en matches the
  # built version's name, so a reshaped wiki page can't move an icon.
  module IconSnapshot
    DEFAULT_PATH = Rails.root.join('data/character_skills/icons.json')
    KEYS = %w[granblue_id style kind position ordinal name_en game_icon].freeze

    class << self
      # Writes every stored version that has a game_icon. Returns the entry count.
      def export(path = DEFAULT_PATH)
        entries = export_rows
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, serialize(entries))
        reset!
        entries.size
      end

      # { [granblue_id, style, kind, position, ordinal] => { name_en:, game_icon: } },
      # memoized per path. An absent file is an empty index.
      def load(path = DEFAULT_PATH)
        @indexes ||= {}
        @indexes[path.to_s] ||= build_index(path)
      end

      # The entry for a version, or nil.
      def lookup(granblue_id:, style:, kind:, position:, ordinal:, path: DEFAULT_PATH)
        load(path)[[granblue_id.to_s, style.to_i, kind.to_s, position.to_i, ordinal.to_i]]
      end

      def reset!
        @indexes = {}
      end

      private

      def build_index(path)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path)).each_with_object({}) do |entry, index|
          key = [entry['granblue_id'].to_s, entry['style'].to_i, entry['kind'].to_s, entry['position'].to_i, entry['ordinal'].to_i]
          index[key] = { name_en: entry['name_en'], game_icon: entry['game_icon'] }
        end
      end

      # One entry per (granblue_id, style, kind, position, ordinal). Older parses
      # left duplicate versions with the same ordinal, name and icon; DISTINCT
      # collapses them.
      def export_rows
        rows = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
          SELECT DISTINCT owner.granblue_id, #{style_sql}, s.kind, s.position, v.ordinal, v.name_en, v.game_icon
          FROM character_skill_versions v
          JOIN character_skills s ON s.id = v.character_skill_id
          #{owner_join_sql}
          WHERE v.game_icon IS NOT NULL
          ORDER BY 1, 2, 3, 4, 5
        SQL
        rows.map do |row|
          KEYS.zip(row).to_h.merge('style' => row[1].to_i, 'position' => row[3].to_i, 'ordinal' => row[4].to_i)
        end
      end

      # Before slots carry their owner row (character_id), every slot belongs to
      # the base row (style_swap: false) for its granblue_id.
      def owner_join_sql
        if owner_key?
          'JOIN characters owner ON owner.id = s.character_id'
        else
          'JOIN characters owner ON owner.granblue_id = s.character_granblue_id AND owner.style_swap = false'
        end
      end

      def style_sql
        'CASE WHEN owner.style_swap THEN 2 ELSE 1 END'
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
