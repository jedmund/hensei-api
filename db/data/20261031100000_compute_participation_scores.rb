# frozen_string_literal: true

# Computes participation scores once on deploy, so Rising and the Gallery's
# Recommended sort have them right away instead of after the first nightly
# sweep. This is the sweep itself: with a 7-day half-life, activity older than
# its window would score 0 anyway. Idempotent; logs counts only.
class ComputeParticipationScores < ActiveRecord::Migration[8.1]
  def up
    PartyParticipation::SweepJob.perform_now
    say "#{Party.where('participation_score > 0').count} parties have a participation score"
  end

  def down
    # Nothing to undo: the nightly sweep keeps the scores current.
  end
end
