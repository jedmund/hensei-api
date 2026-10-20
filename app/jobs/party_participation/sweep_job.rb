# frozen_string_literal: true

module PartyParticipation
  ##
  # Daily sweep that recomputes participation scores. Scores decay every day,
  # so every party with a non-zero score is recomputed, plus any party with
  # sticker, remix or favorite activity inside the activity window.
  #
  # Unlike PartyDifficulty::SweepJob this scores each batch inline: the scorer
  # is set-based (three grouped queries per batch), so per-party jobs would
  # only add overhead.
  class SweepJob < ApplicationJob
    queue_as :maintenance

    # After ten half-lives a contribution is under 0.1% of its original value.
    ACTIVITY_WINDOW = Scorer::DEFAULT_HALF_LIFE * 10
    BATCH_SIZE = 500

    def perform
      now = Time.current
      candidate_scope(now - ACTIVITY_WINDOW).in_batches(of: BATCH_SIZE) do |batch|
        Persister.call(batch.pluck(:id), now: now)
      end
    end

    private

    def candidate_scope(cutoff)
      Party.where('participation_score > 0')
           .or(Party.where(id: PartySticker.where('created_at >= ?', cutoff).select(:party_id)))
           .or(Party.where(id: Favorite.where('created_at >= ?', cutoff).select(:party_id)))
           .or(Party.where(id: Party.where('created_at >= ?', cutoff)
                                    .where.not(source_party_id: nil).select(:source_party_id)))
    end
  end
end
