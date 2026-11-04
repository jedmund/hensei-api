# frozen_string_literal: true

##
# Keeps a party's difficulty score current by enqueueing
# PartyDifficulty::ScoreJob when something that affects the score changes.
#
# Party includes this after its own after_commit hooks, so the recompute
# keeps its place in the commit callback chain.
module Party::DifficultyRecompute
  extend ActiveSupport::Concern

  # Columns whose value actually affects the difficulty score. Edits to other
  # columns (description, shortcode, boost_mod, element, …) do not need to
  # re-trigger the scoring engine, so the after_commit guard skips them.
  SCORING_COLUMNS = %w[weapons_count characters_count summons_count job_id accessory_id
                       ultimate_mastery_level].freeze

  included do
    after_commit :enqueue_difficulty_recompute_if_scoring_changed!, on: %i[create update]
  end

  ##
  # Enqueues a background job to recompute the party's difficulty score.
  # Callers that bypass callbacks (update_column, counter-cache writes) must
  # invoke this directly; the after_commit hook on the model uses the guarded
  # variant below to avoid recomputing on unrelated edits.
  #
  # @return [void]
  def enqueue_difficulty_recompute!
    PartyDifficulty::ScoreJob.perform_later(id) if id.present?
  end

  def enqueue_difficulty_recompute_if_scoring_changed!
    return unless previously_new_record? || saved_changes.keys.intersect?(SCORING_COLUMNS)

    enqueue_difficulty_recompute!
  end
end
