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
  # so a raid isn't empty before anyone has given stickers. For element-themed
  # events (Unite and Fight, Dread Barrage), only parties of the element
  # advantaged against the event's boss are ranked.
  #
  # Returns { raid_id => [party_id, …] } with every raid present (possibly []).
  class EventRanking
    def self.call(**)
      new(**).call
    end

    # raid_ids: the raids to rank parties for, in order
    # window_event: the event whose activity window scores parties, or nil
    # element: integer party element to limit to (element-themed events: the
    #   advantage element), or nil
    def initialize(raid_ids:, window_event:, element: nil, limit: 6, now: Time.current)
      @raid_ids = raid_ids
      @window_event = window_event
      @element = element
      @limit = limit
      @now = now
    end

    def call
      return {} if @raid_ids.empty?

      scores = window_scores
      rows = scores.any? ? Party.where(id: scores.keys).pluck(:id, :raid_id, :element) : []
      by_raid = rows.group_by { |(_id, raid_id, _element)| raid_id }

      @raid_ids.index_with do |raid_id|
        entries = order(by_raid.fetch(raid_id, []).map { |id, _raid, element| [id, element, scores[id]] })
                  .first(@limit)
        entries += top_up(raid_id, entries.map(&:first)) if entries.size < @limit
        entries += recent(raid_id, entries.map(&:first)) if entries.size < @limit
        entries.map(&:first)
      end
    end

    private

    def candidates
      scope = Party.where(raid_id: @raid_ids, visibility: 1)
      scope = scope.where(element: @element) if @element
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

    def top_up(raid_id, taken)
      rows = candidates.where(raid_id: raid_id)
                       .where.not(id: taken)
                       .where('participation_score > 0')
                       .order(participation_score: :desc, id: :asc)
                       .limit(@limit * 4)
                       .pluck(:id, :element, :participation_score)
      order(rows.map { |id, element, score| [id, element, score.to_f] }).first(@limit - taken.size)
    end

    # Unscored public parties, newest first.
    def recent(raid_id, taken)
      scope = candidates.where(raid_id: raid_id).where.not(id: taken)
      scope.order(Arel.sql('last_updated DESC NULLS LAST'), id: :asc)
           .limit(@limit - taken.size)
           .pluck(:id, :element)
    end
  end
end
