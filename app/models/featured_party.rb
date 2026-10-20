# frozen_string_literal: true

# A staff pick, optionally tied to an event. Only public parties can be
# featured.
class FeaturedParty < ApplicationRecord
  belongs_to :event, optional: true
  belongs_to :party

  validates :party_id, uniqueness: { scope: :event_id }
  validates :event, presence: true, if: :event_id?
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :note_en, :note_jp, length: { maximum: 500 }
  validate :party_is_public

  private

  def party_is_public
    errors.add(:party, 'must be public') if party && !party.public?
  end
end
