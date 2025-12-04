# frozen_string_literal: true

class PhantomPlayer < ApplicationRecord
  belongs_to :crew
  belongs_to :claimed_by, class_name: 'User', optional: true
  belongs_to :claimed_from_membership, class_name: 'CrewMembership', optional: true

  has_many :gw_individual_scores, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :granblue_id, length: { maximum: 20 }, allow_blank: true
  validates :granblue_id, uniqueness: { scope: :crew_id }, if: -> { granblue_id.present? }

  validate :claimed_by_must_be_crew_member, if: :claimed_by_id_changed?
  validate :claim_confirmed_requires_claimed_by

  scope :unclaimed, -> { where(claimed_by_id: nil) }
  scope :claimed, -> { where.not(claimed_by_id: nil) }
  scope :pending_confirmation, -> { claimed.where(claim_confirmed: false) }

  # Assign this phantom to a user (officer action)
  def assign_to(user)
    raise CrewErrors::MemberNotFoundError unless user.crew == crew

    self.claimed_by = user
    self.claim_confirmed = false
    save!
  end

  # Confirm the claim (user action)
  def confirm_claim!(user)
    raise CrewErrors::NotClaimedByUserError unless claimed_by == user

    self.claim_confirmed = true
    transfer_scores_to_membership!
    save!
  end

  # Unassign the phantom (officer action or user rejection)
  def unassign!
    self.claimed_by = nil
    self.claim_confirmed = false
    save!
  end

  private

  def claimed_by_must_be_crew_member
    return unless claimed_by.present?
    return if claimed_by.crew == crew

    errors.add(:claimed_by, 'must be a member of this crew')
  end

  def claim_confirmed_requires_claimed_by
    return unless claim_confirmed? && claimed_by.blank?

    errors.add(:claim_confirmed, 'requires a claimed_by user')
  end

  def transfer_scores_to_membership!
    return unless claimed_by.present?

    membership = claimed_by.active_crew_membership
    return unless membership

    # Transfer all phantom scores to the user's membership
    gw_individual_scores.update_all(
      crew_membership_id: membership.id,
      phantom_player_id: nil
    )
  end
end
