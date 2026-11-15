# frozen_string_literal: true

module PartyParticipation
  ##
  # Ranks public parties for each raid linked to an event, at request time.
  #
  # Scores come from Scorer over the window event's activity: half-life is half
  # the window event's length, only stickers given since it was announced
  # count, and ages are measured as of its end (or now, while it's running).
  # For an upcoming event the window event is the previous time it ran.
  #
  # Raids with fewer scored parties than `limit` are topped up from the stored
  # participation_score, then with the most recently updated public parties,
  # so a raid isn't empty before anyone has given stickers. Only parties that
  # meet the Gallery's quality bar (Party.quality) are ranked. For element-themed
  # events (Unite and Fight, Dread Barrage, ...), only parties of the elements
  # advantaged against the event's boss are ranked.
  #
  # Returns { raid_id => [party_id, …] } with every raid present (possibly []).
  class EventRanking
    def self.call(**)
      new(**).call
    end

    # raid_ids: the raids to rank parties for, in order
    # window_event: the event whose activity window scores parties, or nil
    # elements: integer party elements to limit to (element-themed events: the
    #   advantage elements, two for Records of the Ten's Fire and Dark run), or nil
    def initialize(raid_ids:, window_event:, elements: nil, limit: 6, now: Time.current)
      @raid_ids = raid_ids
      @window_event = window_event
      @elements = elements
      @limit = limit
      @now = now
    end

    def call
      return {} if @raid_ids.empty?

      scores = window_scores
      rows = scores.any? ? Party.where(id: scores.keys).pluck(:id, :raid_id, :element) : []
      by_raid = rows.group_by { |(_id, raid_id, _element)| raid_id }

      ranked = @raid_ids.index_with do |raid_id|
        order(by_raid.fetch(raid_id, []).map { |id, _raid, element| [id, element, scores[id]] }).first(@limit)
      end
      fill(ranked) { |raid_ids, taken| top_up(raid_ids, taken) }
      fill(ranked) { |raid_ids, taken| recent(raid_ids, taken) }
      ranked.transform_values { |entries| entries.map(&:first) }
    end

    private

    # Tops up every raid with fewer than `limit` entries from one query for all
    # of them. The block gets those raids and the ids they already hold, and
    # returns { raid_id => [[id, element], …] } best first.
    def fill(ranked)
      short = ranked.select { |_raid_id, entries| entries.size < @limit }
      return if short.empty?

      taken = short.values.flatten(1).map(&:first)
      yield(short.keys, taken).each do |raid_id, entries|
        ranked[raid_id] += entries.first(@limit - ranked[raid_id].size)
      end
    end

    # Each raid's first `limit` rows of `scope` in `order_sql`, as
    # { raid_id => [[column, …], …] } in that order.
    def first_per_raid(scope, order_sql, columns)
      numbered = scope.select(:raid_id, *columns,
                              Arel.sql("ROW_NUMBER() OVER (PARTITION BY parties.raid_id ORDER BY #{order_sql}) AS raid_rank"))
      Party.unscoped.from(numbered, :parties)
           .where(parties: { raid_rank: ..@limit })
           .order(:raid_rank)
           .pluck(:raid_id, *columns)
           .group_by(&:first)
           .transform_values { |rows| rows.map { |row| row.drop(1) } }
    end

    def candidates
      scope = Party.quality.where(raid_id: @raid_ids, visibility: 1)
      scope = scope.where(element: @elements) if @elements
      scope
    end

    def window_scores
      return {} unless @window_event

      as_of = [@now, @window_event.ends_at].min
      Scorer.call(candidates.select(:id),
                  half_life: @window_event.sticker_half_life,
                  since: @window_event.counting_since,
                  as_of: as_of).select { |_id, score| score.positive? }
    end

    # Entries are [id, element, score]; returns them as [id, element], best first.
    def order(entries)
      entries.sort_by { |id, _element, score| [-score, id] }
             .map { |id, element, _score| [id, element] }
    end

    # Parties by stored participation_score, best first.
    def top_up(raid_ids, taken)
      scope = candidates.where(raid_id: raid_ids).where.not(id: taken).where('parties.participation_score > 0')
      first_per_raid(scope, 'parties.participation_score DESC, parties.id ASC', %i[id element participation_score])
        .transform_values { |rows| order(rows.map { |id, element, score| [id, element, score.to_f] }) }
    end

    # Unscored public parties, newest first.
    def recent(raid_ids, taken)
      scope = candidates.where(raid_id: raid_ids).where.not(id: taken)
      first_per_raid(scope, 'parties.last_updated DESC NULLS LAST, parties.id ASC', %i[id element])
    end
  end
end
