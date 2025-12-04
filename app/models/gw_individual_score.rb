# frozen_string_literal: true

class GwIndividualScore < ApplicationRecord
  belongs_to :crew_gw_participation
  belongs_to :crew_membership, optional: true
  belongs_to :phantom_player, optional: true
  belongs_to :recorded_by, class_name: 'User'

  # Use same round enum as GwCrewScore
  enum :round, GwCrewScore::ROUNDS

  validates :round, presence: true
  validates :score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :crew_membership_id, uniqueness: {
    scope: %i[crew_gw_participation_id round],
    message: 'already has a score for this round'
  }, if: -> { crew_membership_id.present? }
  validates :phantom_player_id, uniqueness: {
    scope: %i[crew_gw_participation_id round],
    message: 'already has a score for this round'
  }, if: -> { phantom_player_id.present? }

  validate :membership_belongs_to_crew
  validate :phantom_belongs_to_crew
  validate :exactly_one_player_reference

  delegate :crew, :gw_event, to: :crew_gw_participation

  scope :for_round, ->(round) { where(round: round) }
  scope :for_membership, ->(membership) { where(crew_membership: membership) }
  scope :for_phantom, ->(phantom) { where(phantom_player: phantom) }

  # Returns the player name (from membership user or phantom)
  def player_name
    if crew_membership.present?
      crew_membership.user.username
    elsif phantom_player.present?
      phantom_player.name
    end
  end

  private

  def membership_belongs_to_crew
    return unless crew_membership.present?

    unless crew_membership.crew_id == crew_gw_participation.crew_id
      errors.add(:crew_membership, 'must belong to the participating crew')
    end
  end

  def phantom_belongs_to_crew
    return unless phantom_player.present?

    unless phantom_player.crew_id == crew_gw_participation.crew_id
      errors.add(:phantom_player, 'must belong to the participating crew')
    end
  end

  def exactly_one_player_reference
    has_membership = crew_membership_id.present?
    has_phantom = phantom_player_id.present?

    if has_membership && has_phantom
      errors.add(:base, 'cannot have both crew_membership and phantom_player')
    elsif !has_membership && !has_phantom
      errors.add(:base, 'must have either crew_membership or phantom_player')
    end
  end
end
