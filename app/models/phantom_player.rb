# frozen_string_literal: true

class PhantomPlayer < ApplicationRecord
  belongs_to :crew
  belongs_to :claimed_by, class_name: 'User', optional: true
  belongs_to :claimed_from_membership, class_name: 'CrewMembership', optional: true

  has_many :gw_individual_scores, dependent: :nullify

  before_validation :set_joined_at, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :granblue_id, length: { maximum: 20 }, allow_blank: true
  validates :granblue_id, uniqueness: { scope: :crew_id }, if: -> { granblue_id.present? }

  validate :claimed_by_must_be_crew_member, if: :claimed_by_id_changed?
  validate :claim_confirmed_requires_claimed_by

  scope :unclaimed, -> { where(claimed_by_id: nil) }
  scope :claimed, -> { where.not(claimed_by_id: nil) }
  scope :pending_confirmation, -> { claimed.where(claim_confirmed: false) }
  scope :active, -> { where(retired: false) }
  scope :retired, -> { where(retired: true) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Phantoms who were active during a date range (either still active, or retired after the end date)
  # Uses joined_at (editable) instead of created_at for historical accuracy
  scope :active_during, ->(start_date, end_date) {
    where('retired = false OR retired_at >= ?', start_date)
      .where('joined_at <= ?', end_date)
  }

  # Assign this phantom to a user (officer action)
  def assign_to(user)
    raise CrewErrors::MemberNotFoundError unless user.crew == crew

    self.claimed_by = user
    self.claim_confirmed = false
    save!
  end

  # Confirm the claim (user action)
  # After confirmation, soft deletes the phantom since scores have been transferred
  def confirm_claim!(user)
    raise CrewErrors::NotClaimedByUserError unless claimed_by == user

    self.claim_confirmed = true
    self.deleted_at = Time.current
    transfer_to_membership!
    save!
  end

  # Soft delete the phantom (keeps record for logging)
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  # Unassign the phantom (officer action or user rejection)
  def unassign!
    self.claimed_by = nil
    self.claim_confirmed = false
    save!
  end

  # Retire the phantom player (keeps scores)
  def retire!
    update!(retired: true, retired_at: Time.current)
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end

  def claimed_by_must_be_crew_member
    return unless claimed_by.present?
    return if claimed_by.crew == crew

    errors.add(:claimed_by, 'must be a member of this crew')
  end

  def claim_confirmed_requires_claimed_by
    return unless claim_confirmed? && claimed_by.blank?

    errors.add(:claim_confirmed, 'requires a claimed_by user')
  end

  def transfer_to_membership!
    return unless claimed_by.present?

    membership = claimed_by.active_crew_membership
    return unless membership

    gw_individual_scores.update_all(
      crew_membership_id: membership.id,
      phantom_player_id: nil
    )

    if joined_at.present? && (membership.joined_at.nil? || joined_at < membership.joined_at)
      membership.update_columns(joined_at: joined_at)
    end
  end
end
