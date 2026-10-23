# frozen_string_literal: true

module SummonAuras
  module Build
    # What a summon's auras are built from, as one SHA256:
    #   - Build::VERSION;
    #   - the sha256 of the summon's wiki_raw `sources` row ("-" when there is none);
    #   - the summons columns the extractor reads: granblue_id and element;
    #   - its series slug (Odious and Magna summons' frames are told apart by it).
    # Stored on summons.summon_aura_build_fingerprint after a write; a run without all: true
    # skips summons whose fingerprint still matches.
    #
    # Two paths produce the same digest:
    #   - #for(summon) reads an in-memory record;
    #   - #for_relation(relation) reads only the rows' sha256, so a deploy loads no page text
    #     just to find nothing stale.
    class Fingerprint
      SOURCES = %w[wiki_raw].freeze
      # Columns besides the sources that change the build's output. A series is read by its slug.
      ATTRIBUTES = %w[granblue_id element summon_series_id].freeze
      NONE = "-"

      def for(summon)
        combine(summon.source_sha256(:wiki_raw), summon.granblue_id, summon.element, summon.summon_series_id)
      end

      # → { summon id => fingerprint } for every summon in relation, without loading any
      # source body.
      def for_relation(relation)
        rows = relation.pluck(:id, *ATTRIBUTES)
        shas = Source.where(owner_type: Summon.polymorphic_name, owner_id: rows.map(&:first), kind: SOURCES, key: "")
                     .pluck(:owner_id, :sha256).to_h
        rows.to_h { |id, *values| [id, combine(shas[id], *values)] }
      end

      private

      def combine(wiki_sha, granblue_id, element, series_id)
        parts = ["version:#{VERSION}", "wiki_raw:#{wiki_sha || NONE}", "granblue_id:#{granblue_id || NONE}",
                 "element:#{element || NONE}", "series:#{series_slugs[series_id] || NONE}"]
        Digest::SHA256.hexdigest(parts.join("\n"))
      end

      def series_slugs
        @series_slugs ||= SummonSeries.pluck(:id, :slug).to_h
      end
    end
  end
end
