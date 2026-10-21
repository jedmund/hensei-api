# frozen_string_literal: true

module CharacterSkills
  module Build
    # What a character's skills are built from, as one SHA256 (contract C5, plus D15):
    #   - Build::VERSION;
    #   - the sha256 of the character's wiki_raw, wiki_raw_jp, game_raw_en and game_raw_jp
    #     `sources` rows ("-" when there is none), and of its jp_skill_text row when it has one
    #     (an optional input: absent, it adds nothing, so other characters' digests don't move);
    #   - the other characters columns the Builder reads: granblue_id, element, style_swap;
    #   - the statuses catalogue, (id, name_en, category) sorted (a name resolves by category);
    #   - the sha256 of the icon snapshot file, or "-" when it's absent.
    # Stored on characters.character_skill_build_fingerprint after a write; a run without
    # all: true skips characters whose fingerprint still matches.
    #
    # A source's sha256 is the digest of its stored body; JSON payloads are stored as
    # canonical JSON, so their digest is the one the jsonb columns had before the move (D35).
    #
    # Two paths produce the same digest:
    #   - #for(character) reads an in-memory record (staged, unsaved text included, for previews);
    #   - #for_relation(relation) reads only the rows' sha256, so a deploy loads no page text
    #     just to find nothing stale.
    class Fingerprint
      REQUIRED_SOURCES = %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp].freeze
      OPTIONAL_SOURCES = %w[jp_skill_text].freeze
      SOURCES = (REQUIRED_SOURCES + OPTIONAL_SOURCES).freeze
      # Columns besides the sources that change the Builder's output (D15).
      ATTRIBUTES = %w[granblue_id element style_swap].freeze
      NONE = "-"

      # The snapshot the Builder reads its fallback icons from.
      def self.icon_snapshot_path = IconSnapshot::DEFAULT_PATH

      # One instance per run: the statuses and icons digests are computed once, after the
      # status catalogue has been refreshed.
      def initialize(icon_snapshot_path: self.class.icon_snapshot_path)
        @icon_snapshot_path = icon_snapshot_path
      end

      def for(character)
        digests = SOURCES.to_h { |kind| [kind, character.source_sha256(kind) || NONE] }
        combine(digests, ATTRIBUTES.to_h { |column| [column, character[column]] })
      end

      # → { character id => fingerprint } for every character in relation, without loading
      # any source body.
      def for_relation(relation)
        rows = relation.pluck(:id, *ATTRIBUTES)
        shas = Source.where(owner_type: Character.polymorphic_name, owner_id: rows.map(&:first), kind: SOURCES, key: "")
                     .pluck(:owner_id, :kind, :sha256)
                     .each_with_object(Hash.new { |h, k| h[k] = {} }) { |(id, kind, sha), by_id| by_id[id][kind] = sha }
        rows.to_h do |id, *values|
          digests = SOURCES.to_h { |kind| [kind, shas.dig(id, kind) || NONE] }
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
        parts += REQUIRED_SOURCES.map { |kind| "#{kind}:#{digests.fetch(kind)}" }
        parts += OPTIONAL_SOURCES.filter_map { |kind| "#{kind}:#{digests[kind]}" if digests[kind] && digests[kind] != NONE }
        parts += ATTRIBUTES.map { |column| "#{column}:#{attributes[column].nil? ? NONE : attributes[column]}" }
        Digest::SHA256.hexdigest(parts.join("\n"))
      end
    end
  end
end
