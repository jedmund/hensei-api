# frozen_string_literal: true

module PartyParticipation
  ##
  # Recomputes and stores `participation_score` for the given parties with the
  # default half-life. Non-public parties are stored as 0 so they drop out of
  # rankings until they're public again (their stickers are kept).
  #
  # Writes with update_all so updated_at isn't bumped and no callbacks (such as
  # the difficulty recompute) fire.
  class Persister
    # Scores below this are stored as 0 so long-decayed parties leave the sweep.
    MIN_SCORE = 0.001

    def self.call(party_ids, now: Time.current)
      new(party_ids, now: now).call
    end

    def initialize(party_ids, now:)
      @party_ids = Array(party_ids).compact.uniq
      @now = now
    end

    def call
      return {} if @party_ids.empty?

      public_ids = Party.where(id: @party_ids, visibility: 1).pluck(:id)
      scores = Scorer.call(public_ids, as_of: @now)

      results = Party.where(id: @party_ids).pluck(:id).to_h do |id|
        value = scores[id].to_f
        [id, value < MIN_SCORE ? 0 : value.round(4)]
      end

      results.group_by { |_id, score| score }.each do |score, rows|
        Party.where(id: rows.map(&:first))
             .update_all(participation_score: score, participation_computed_at: @now)
      end

      results
    end
  end
end
