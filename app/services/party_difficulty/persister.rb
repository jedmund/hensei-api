# frozen_string_literal: true

module PartyDifficulty
  ##
  # Computes a party's difficulty via Calculator and persists the result via
  # update_columns (so it doesn't trigger after_commit callbacks and recurse).
  #
  # When a party is not scoreable (doesn't meet the min_count thresholds), all
  # five difficulty columns are nulled so the UI hides the badge.
  class Persister
    def self.call(party_id)
      party = Calculator.eager_load_party(party_id)
      result = Calculator.new(party).call

      if result.scoreable
        party.update_columns(
          difficulty_id: result.difficulty&.id,
          difficulty_score: result.score,
          difficulty_breakdown: result.breakdown,
          difficulty_computed_at: Time.current,
          difficulty_ruleset_version: result.ruleset_version
        )
      else
        # Leave difficulty_computed_at nil so the daily sweep picks the party
        # back up the moment it crosses the scoreability threshold (e.g. via a
        # counter-cache update that bypassed the Party after_commit callback).
        party.update_columns(
          difficulty_id: nil,
          difficulty_score: nil,
          difficulty_breakdown: nil,
          difficulty_computed_at: nil,
          difficulty_ruleset_version: result.ruleset_version
        )
      end

      result
    end
  end
end
