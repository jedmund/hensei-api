# frozen_string_literal: true

class GwIndividualScore < ApplicationRecord
  belongs_to :crew_gw_participation
  belongs_to :crew_membership, optional: true
  belongs_to :recorded_by, class_name: 'User'

  # Use same round enum as GwCrewScore
  enum :round, GwCrewScore::ROUNDS

  validates :round, presence: true
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :crew_membership_id, uniqueness: {
    scope: %i[crew_gw_participation_id round],
    message: 'already has a score for this round'
  }, if: -> { crew_membership_id.present? }

  validate :membership_belongs_to_crew

  delegate :crew, :gw_event, to: :crew_gw_participation

  scope :for_round, ->(round) { where(round: round) }
  scope :for_membership, ->(membership) { where(crew_membership: membership) }

  private

  def membership_belongs_to_crew
    return unless crew_membership.present?

    unless crew_membership.crew_id == crew_gw_participation.crew_id
      errors.add(:crew_membership, 'must belong to the participating crew')
    end
  end
end
