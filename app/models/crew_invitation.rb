# frozen_string_literal: true

class CrewInvitation < ApplicationRecord
  belongs_to :crew
  belongs_to :user
  belongs_to :invited_by, class_name: 'User'
  belongs_to :phantom_player, optional: true

  enum :status, { pending: 0, accepted: 1, rejected: 2, expired: 3 }

  validates :user_id, uniqueness: {
    scope: %i[crew_id status],
    conditions: -> { where(status: :pending) },
    message: 'already has a pending invitation to this crew'
  }

  validate :user_not_in_crew, on: :create
  validate :inviter_is_officer
  validate :phantom_belongs_to_crew, if: :phantom_player_id_changed?

  scope :active, -> { where(status: :pending).where('expires_at IS NULL OR expires_at > ?', Time.current) }

  before_create :set_expiration

  # Accept the invitation and create membership
  # If a phantom was pre-assigned, auto-assign it to the new member
  def accept!
    raise CrewErrors::InvitationExpiredError if expired? || (expires_at.present? && expires_at < Time.current)
    raise CrewErrors::AlreadyInCrewError if user.reload.crew.present?

    transaction do
      update!(status: :accepted)
      CrewMembership.create!(crew: crew, user: user, role: :member)

      if phantom_player.present? && phantom_player.claimed_by_id.nil?
        user.reload
        phantom_player.assign_to(user)
      end
    end
  end

  # Reject the invitation
  def reject!
    raise CrewErrors::InvitationExpiredError if expired?

    update!(status: :rejected)
  end

  # Check if invitation is still valid
  def active?
    pending? && (expires_at.nil? || expires_at > Time.current)
  end

  private

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end

  def user_not_in_crew
    return unless user&.crew.present?

    errors.add(:user, 'is already in a crew')
  end

  def inviter_is_officer
    return unless invited_by.present?
    return if invited_by.crew&.id == crew_id && invited_by.crew_officer?

    errors.add(:invited_by, 'must be an officer of the crew')
  end

  def phantom_belongs_to_crew
    return unless phantom_player.present?
    return if phantom_player.crew_id == crew_id

    errors.add(:phantom_player, 'must belong to the same crew')
  end
end
