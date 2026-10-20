# frozen_string_literal: true

module CharacterSkills
  module Build
    # What a character's skills are built from, as one SHA256 (contract C5, plus D15):
    #   - Build::VERSION;
    #   - the row's wiki_raw, wiki_raw_jp, game_raw_en and game_raw_jp, each as its own sha256
    #     ("-" for nil);
    #   - the other characters columns the Builder reads: granblue_id, element, style_swap;
    #   - the statuses catalogue, (id, name_en, category) sorted (a name resolves by category);
    #   - the sha256 of the icon snapshot file, or "-" when it's absent.
    # Stored on characters.character_skill_build_fingerprint after a write; a run without
    # all: true skips characters whose fingerprint still matches.
    #
    # Two paths produce the same digest:
    #   - #for(character) hashes an in-memory record (unsaved text included, for previews);
    #   - #for_relation(relation) hashes the text columns in SQL, so a deploy doesn't load
    #     every page's text (wiki_raw_jp alone is ~190 MB) just to find nothing stale.
    # The jsonb columns are hashed in Ruby on both paths, as canonical JSON (sorted keys).
    class Fingerprint
      TEXT_SOURCES = %w[wiki_raw wiki_raw_jp].freeze
      JSON_SOURCES = %w[game_raw_en game_raw_jp].freeze
      SOURCES = (TEXT_SOURCES + JSON_SOURCES).freeze
      # Columns besides the sources that change the Builder's output (D15).
      ATTRIBUTES = %w[granblue_id element style_swap].freeze
      # What the on-save callback watches.
      INPUT_COLUMNS = (SOURCES + ATTRIBUTES).freeze
      NONE = "-"

      # The snapshot the Builder reads its fallback icons from.
      def self.icon_snapshot_path = IconSnapshot::DEFAULT_PATH

      # One instance per run: the statuses and icon digests are computed once, after the
      # status catalogue has been refreshed.
      def initialize(icon_snapshot_path: self.class.icon_snapshot_path)
        @icon_snapshot_path = icon_snapshot_path
      end

      def for(character)
        digests = TEXT_SOURCES.to_h { |column| [column, text_digest(character[column])] }
        JSON_SOURCES.each { |column| digests[column] = json_digest(character[column]) }
        combine(digests, ATTRIBUTES.to_h { |column| [column, character[column]] })
      end

      # → { character id => fingerprint } for every character in relation, without loading
      # the text columns.
      def for_relation(relation)
        text_sql = TEXT_SOURCES.map do |column|
          Arel.sql("encode(sha256(convert_to(characters.#{column}, 'UTF8')), 'hex')")
        end
        relation.pluck(:id, *text_sql, *JSON_SOURCES, *ATTRIBUTES).to_h do |id, *values|
          texts = values.shift(TEXT_SOURCES.size)
          jsons = values.shift(JSON_SOURCES.size)
          digests = TEXT_SOURCES.zip(texts).to_h { |column, sha| [column, sha || NONE] }
          JSON_SOURCES.zip(jsons).each { |column, value| digests[column] = json_digest(value) }
          [id, combine(digests, ATTRIBUTES.zip(values).to_h)]
        end
      end

      def statuses_digest
        @statuses_digest ||= Digest::SHA256.hexdigest(
          Status.pluck(:id, :name_en, :category).sort_by { |id, *| id.to_s }
                .map { |id, name, category| "#{id}:#{name}:#{category}" }.join("\n")
        )
      end

      def icons_digest
        @icons_digest ||= File.file?(@icon_snapshot_path) ? Digest::SHA256.file(@icon_snapshot_path).hexdigest : NONE
      end

      private

      def combine(digests, attributes)
        parts = ["version:#{VERSION}", "statuses:#{statuses_digest}", "icons:#{icons_digest}"]
        parts += SOURCES.map { |column| "#{column}:#{digests.fetch(column)}" }
        parts += ATTRIBUTES.map { |column| "#{column}:#{attributes[column].nil? ? NONE : attributes[column]}" }
        Digest::SHA256.hexdigest(parts.join("\n"))
      end

      def text_digest(value)
        value.nil? ? NONE : Digest::SHA256.hexdigest(value.to_s)
      end

      # A jsonb value (Hash, Array, or a String the old import stored) as canonical JSON.
      def json_digest(value)
        value.nil? ? NONE : Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
      end

      def canonical(value)
        case value
        when Hash then value.sort_by { |k, _| k.to_s }.to_h { |k, v| [k.to_s, canonical(v)] }
        when Array then value.map { |v| canonical(v) }
        else value
        end
      end
    end
  end
end
