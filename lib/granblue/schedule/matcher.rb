# frozen_string_literal: true

module Granblue
  module Schedule
    # Merges normalized records from the wiki and the official post into
    # candidate events. Records pair one-to-one across sources (never within
    # one), best match first, by how much their time windows overlap, with name
    # similarity and kind agreement as tie-breakers. Where the paired records
    # disagree, the candidate lists the difference instead of hiding it.
    #
    #   candidates = Matcher.new.match(wiki: wiki_records, official: official_records)
    #
    # Each candidate:
    #   { name_en:, name_jp:, starts_at:, ends_at:, kind_guess:, element:,
    #     image_en:, image_jp:,
    #     sources: { 'gbf_wiki' => record, 'official_site' => record },  # one or both
    #     disagreements: [{ field:, 'gbf_wiki' => value, 'official_site' => value }],
    #     alternatives: [{ source:, source_id:, overlap: }],  # other plausible pairings
    #     overlap:, name_similarity: }                       # nil when single-source
    #
    # Field choice when both sources have a value: times and element come from
    # the official post (the official schedule), kind from the wiki, each name
    # from its own language's source. Every such choice that hides a different
    # value is listed in disagreements.
    class Matcher
      WIKI = WikiSource::SOURCE
      OFFICIAL = OfficialPostSource::SOURCE

      # Times within a minute count as equal: the official post ends events at
      # 16:59 where another source may write 17:00.
      TIME_TOLERANCE = 60

      def initialize(min_overlap: 0.5, name_threshold: 0.6)
        @min_overlap = min_overlap
        @name_threshold = name_threshold
      end

      def match(wiki:, official:)
        pairs = scored_pairs(wiki, official)
        accepted = select_pairs(pairs)
        used_wiki = accepted.to_set { |pair| pair[:wiki] }.compare_by_identity
        used_official = accepted.to_set { |pair| pair[:official] }.compare_by_identity

        candidates = accepted.map { |pair| merge(pair, alternatives_for(pair, pairs, accepted)) }
        candidates += wiki.reject { |r| used_wiki.include?(r) }.map { |r| single(r) }
        candidates += official.reject { |r| used_official.include?(r) }.map { |r| single(r) }
        candidates.sort_by { |c| [c[:starts_at], c[:name_en] || c[:name_jp] || ''] }
      end

      # Bigram Dice coefficient over NFKC-normalized, lowercased letters and
      # digits. 1.0 for equal names, 0.0 when either is blank.
      def self.name_similarity(left, right)
        a = normalize_name(left)
        b = normalize_name(right)
        return 0.0 if a.empty? || b.empty?
        return 1.0 if a == b

        grams_a = bigrams(a)
        grams_b = bigrams(b)
        return 0.0 if grams_a.empty? || grams_b.empty?

        common = grams_a.tally.sum { |gram, count| [count, grams_b.count(gram)].min }
        (2.0 * common) / (grams_a.size + grams_b.size)
      end

      def self.normalize_name(name)
        name.to_s.unicode_normalize(:nfkc).downcase.gsub(/[^\p{L}\p{N}]/, '')
      end

      def self.bigrams(text)
        text.chars.each_cons(2).map(&:join)
      end

      # Intersection over union of two windows, 0.0 when they only touch.
      def self.overlap(left, right)
        inter = [left[:ends_at], right[:ends_at]].min - [left[:starts_at], right[:starts_at]].max
        return 0.0 unless inter.positive?

        union = [left[:ends_at], right[:ends_at]].max - [left[:starts_at], right[:starts_at]].min
        inter / union
      end

      private

      def scored_pairs(wiki, official)
        wiki.product(official).filter_map do |w, o|
          overlap = self.class.overlap(w, o)
          next if overlap.zero?

          similarity = best_name_similarity(w, o)
          kind_conflict = w[:kind_guess] && o[:kind_guess] && w[:kind_guess] != o[:kind_guess]
          { wiki: w, official: o, overlap: overlap, name_similarity: similarity,
            score: overlap + (0.5 * similarity) - (kind_conflict ? 0.25 : 0),
            acceptable: acceptable?(w, o, overlap, similarity) }
        end
      end

      def acceptable?(wiki, official, overlap, similarity)
        overlap >= @min_overlap ||
          same_time?(wiki[:starts_at], official[:starts_at]) ||
          similarity >= @name_threshold
      end

      # Greedy one-to-one assignment, best score first.
      def select_pairs(pairs)
        taken_wiki = Set.new.compare_by_identity
        taken_official = Set.new.compare_by_identity
        pairs.select { |pair| pair[:acceptable] }.sort_by { |pair| -pair[:score] }.select do |pair|
          next false if taken_wiki.include?(pair[:wiki]) || taken_official.include?(pair[:official])

          taken_wiki << pair[:wiki]
          taken_official << pair[:official]
        end
      end

      # Other acceptable pairings that involved either record of this pair.
      def alternatives_for(pair, pairs, accepted)
        pairs.filter_map do |other|
          next if other.equal?(pair) || !other[:acceptable] || accepted.include?(other)

          if other[:wiki].equal?(pair[:wiki])
            alternative(other[:official], other)
          elsif other[:official].equal?(pair[:official])
            alternative(other[:wiki], other)
          end
        end
      end

      def alternative(record, pair)
        { source: record[:source], source_id: record[:source_id], overlap: pair[:overlap].round(3) }
      end

      def best_name_similarity(wiki, official)
        [
          self.class.name_similarity(wiki[:name_en], official[:name_en]),
          self.class.name_similarity(wiki[:name_jp], official[:name_jp]),
          self.class.name_similarity(wiki[:name_en], official[:name_jp]),
          self.class.name_similarity(wiki[:name_jp], official[:name_en])
        ].max
      end

      def merge(pair, alternatives)
        w = pair[:wiki]
        o = pair[:official]
        {
          name_en: w[:name_en] || o[:name_en],
          name_jp: o[:name_jp] || w[:name_jp],
          starts_at: o[:starts_at],
          ends_at: o[:ends_at],
          kind_guess: w[:kind_guess] || o[:kind_guess],
          element: o[:element] || w[:element],
          image_en: w[:image_en] || o[:image_en],
          image_jp: o[:image_jp] || w[:image_jp],
          sources: { WIKI => w, OFFICIAL => o },
          disagreements: disagreements(w, o),
          alternatives: alternatives,
          overlap: pair[:overlap].round(3),
          name_similarity: pair[:name_similarity].round(3)
        }
      end

      def single(record)
        record.slice(:name_en, :name_jp, :starts_at, :ends_at, :kind_guess, :element, :image_en, :image_jp).merge(
          sources: { record[:source] => record }, disagreements: [], alternatives: [],
          overlap: nil, name_similarity: nil
        )
      end

      def disagreements(wiki, official)
        list = %i[starts_at ends_at].filter_map do |field|
          next if same_time?(wiki[field], official[field])

          { field: field, WIKI => wiki[field], OFFICIAL => official[field] }
        end
        %i[kind_guess element].each do |field|
          next if wiki[field].nil? || official[field].nil? || wiki[field] == official[field]

          list << { field: field, WIKI => wiki[field], OFFICIAL => official[field] }
        end
        list
      end

      def same_time?(left, right)
        (left - right).abs <= TIME_TOLERANCE
      end
    end
  end
end
