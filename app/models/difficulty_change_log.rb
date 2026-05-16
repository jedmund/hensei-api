# frozen_string_literal: true

##
# Append-only audit log of editor commits against the difficulty ruleset.
# Recorded by PartyDifficulty::DraftWorkspace#commit!. Not surfaced anywhere
# yet — kept for future audit / undo / diff history features.
class DifficultyChangeLog < ApplicationRecord
  belongs_to :user

  scope :recent_first, -> { order(committed_at: :desc) }
end
