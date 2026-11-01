# frozen_string_literal: true

# A staff pick, optionally tied to an event. Only public parties can be
# featured. A pick for an event shows on Home while the event is running or
# upcoming; a general pick (no event) for GENERAL_WINDOW after it was made.
class FeaturedParty < ApplicationRecord
  include ExpiresHomeFeed

  GENERAL_WINDOW = 30.days

  belongs_to :event, optional: true
  belongs_to :party

  validates :party_id, uniqueness: { scope: :event_id }
  validates :event, presence: true, if: :event_id?
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :note_en, :note_jp, length: { maximum: 500 }
  validate :party_is_public

  scope :general, -> { where(event_id: nil) }
  # General picks whose window has passed
  scope :expired, ->(now = Time.current) { general.where(created_at: ..(now - GENERAL_WINDOW)) }

  # When a general pick leaves Home; nil for event picks, which follow their event.
  def expires_at
    created_at + GENERAL_WINDOW if event_id.nil? && created_at
  end

  private

  def party_is_public
    errors.add(:party, 'must be public') if party && !party.public?
  end
end
