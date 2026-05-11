# frozen_string_literal: true

module PartyDifficulty
  ##
  # Daily sweep that recomputes difficulty for parties with a stale value.
  # A party is considered stale when:
  #   - difficulty_computed_at is older than STALE_AFTER (30 days), OR
  #   - difficulty_ruleset_version is below the current version (rules changed), OR
  #   - the party has never been scored AND meets the scoreability threshold
  #
  # Pages through stale parties in batches and enqueues a ScoreJob for each.
  # The actual scoring happens in ScoreJob so failures are isolated per-party.
  class SweepJob < ApplicationJob
    queue_as :maintenance

    STALE_AFTER = 30.days
    BATCH_SIZE = 500

    def perform
      current_version = DifficultyConfig.current_version
      stale_cutoff = STALE_AFTER.ago

      stale_scope(current_version, stale_cutoff).find_in_batches(batch_size: BATCH_SIZE) do |batch|
        batch.each { |party| ScoreJob.perform_later(party.id) }
      end
    end

    private

    def stale_scope(current_version, stale_cutoff)
      enabled = DifficultyComponent.enabled.index_by(&:name)
      min_weapons = enabled['weapon']&.min_count_to_score.to_i
      min_chars = enabled['character']&.min_count_to_score.to_i
      min_summons = enabled['summon']&.min_count_to_score.to_i

      Party
        .where('weapons_count >= ? AND characters_count >= ? AND summons_count >= ?',
               min_weapons, min_chars, min_summons)
        .where(
          'difficulty_computed_at IS NULL OR difficulty_computed_at < ? OR difficulty_ruleset_version IS NULL OR difficulty_ruleset_version < ?',
          stale_cutoff, current_version
        )
    end
  end
end
