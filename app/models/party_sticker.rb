# frozen_string_literal: true

# One user's sticker on one party. The unique (user_id, party_id) index keeps
# it to one per user per team; changing a sticker updates this row.
class PartySticker < ApplicationRecord
  # A team's label is the sticker given most among its last this many.
  RECENT_FOR_LABEL = 10

  belongs_to :user
  belongs_to :party
  belongs_to :sticker

  # Where it sits in the sticker area (see the migration).
  X_RANGE = (0.0..1.0)
  Y_RANGE = (0.0..400.0)
  ROTATION_RANGE = (-45.0..45.0)

  validates :party_id, uniqueness: { scope: :user_id }
  # Must be numbers (as sent, so "abc" isn't read as 0); out of range is
  # clamped on save, so a drop at the very edge still lands
  validates :x, :y, :rotation, numericality: true, allow_nil: true
  before_save :clamp_placement

  private

  def clamp_placement
    self.x = x.clamp(X_RANGE.begin, X_RANGE.end) unless x.nil?
    self.y = y.clamp(Y_RANGE.begin, Y_RANGE.end) unless y.nil?
    self.rotation = rotation.clamp(ROTATION_RANGE.begin, ROTATION_RANGE.end) unless rotation.nil?
  end
end
