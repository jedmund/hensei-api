# frozen_string_literal: true

class Crew < ApplicationRecord
  has_many :crew_memberships, dependent: :destroy
  has_many :users, through: :crew_memberships
  has_many :active_memberships, -> { where(retired: false) }, class_name: 'CrewMembership'
  has_many :active_members, through: :active_memberships, source: :user
  has_many :crew_invitations, dependent: :destroy
  has_many :pending_invitations, -> { where(status: :pending) }, class_name: 'CrewInvitation'
  has_many :crew_gw_participations, dependent: :destroy
  has_many :gw_events, through: :crew_gw_participations
  has_many :phantom_players, dependent: :destroy
  has_many :crew_rosters, dependent: :destroy
  has_many :party_shares, as: :shareable, dependent: :destroy
  has_many :shared_parties, through: :party_shares, source: :party

  validates :name, presence: true, length: { maximum: 100 }
  validates :gamertag, length: { maximum: 4 }, uniqueness: { case_sensitive: false }, allow_nil: true
  validates :granblue_crew_id, uniqueness: true, allow_nil: true

  def captain
    crew_memberships.includes(user: { active_crew_membership: :crew })
                    .find_by(role: :captain, retired: false)&.user
  end

  def vice_captains
    crew_memberships.where(role: :vice_captain, retired: false)
                    .includes(user: { active_crew_membership: :crew })
                    .map(&:user)
  end

  def officers
    crew_memberships.where(role: [:captain, :vice_captain], retired: false).includes(:user).map(&:user)
  end

  def member_count
    active_memberships.count
  end

  def blueprint
    CrewBlueprint
  end
end
