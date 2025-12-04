# frozen_string_literal: true

class CrewMembership < ApplicationRecord
  belongs_to :crew
  belongs_to :user

  enum :role, { member: 0, vice_captain: 1, captain: 2 }

  validates :user_id, uniqueness: { scope: :crew_id }
  validate :one_active_crew_per_user, on: :create
  validate :captain_limit
  validate :vice_captain_limit

  scope :active, -> { where(retired: false) }
  scope :retired, -> { where(retired: true) }

  def retire!
    update!(retired: true, retired_at: Time.current, role: :member)
  end

  def blueprint
    CrewMembershipBlueprint
  end

  private

  def one_active_crew_per_user
    return if retired

    if CrewMembership.where(user_id: user_id, retired: false).where.not(id: id).exists?
      errors.add(:user, 'can only be in one active crew')
    end
  end

  def captain_limit
    return unless captain? && !retired

    existing = crew.crew_memberships.where(role: :captain, retired: false).where.not(id: id)
    errors.add(:role, 'crew can only have one captain') if existing.exists?
  end

  def vice_captain_limit
    return unless vice_captain? && !retired

    existing = crew.crew_memberships.where(role: :vice_captain, retired: false).where.not(id: id)
    errors.add(:role, 'crew can only have up to 3 vice captains') if existing.count >= 3
  end
end
