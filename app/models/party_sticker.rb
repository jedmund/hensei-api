# frozen_string_literal: true

# One user's sticker on one party. The unique (user_id, party_id) index keeps
# it to one per user per team; changing a sticker updates this row.
class PartySticker < ApplicationRecord
  # Distinct users who must give an active sticker before it shows as a label.
  STICKER_LABEL_THRESHOLD = 5
  # Labels shown on a team, most given first.
  MAX_LABELS = 2

  belongs_to :user
  belongs_to :party
  belongs_to :sticker

  validates :party_id, uniqueness: { scope: :user_id }

  after_commit :enqueue_participation_recompute

  private

  def enqueue_participation_recompute
    PartyParticipation::ScoreJob.perform_later(party_id) if party_id.present?
  end
end
