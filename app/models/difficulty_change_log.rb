# frozen_string_literal: true

##
# Append-only audit log of editor commits against the difficulty ruleset.
# Recorded by PartyDifficulty::DraftWorkspace#commit!. Not surfaced anywhere
# yet — kept for future audit / undo / diff history features.
class DifficultyChangeLog < ApplicationRecord
  # Optional once saved: the user may delete their account later, which clears
  # this. New records still need one.
  belongs_to :user, optional: true
  validates :user, presence: true, on: :create

  scope :recent_first, -> { order(committed_at: :desc) }
end
