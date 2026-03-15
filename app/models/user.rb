# frozen_string_literal: true

class User < ApplicationRecord
  before_save { self.email = email&.downcase }

  ##### ActiveRecord Associations
  has_many :parties, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :collection_characters, dependent: :destroy
  has_many :collection_weapons, dependent: :destroy
  has_many :collection_summons, dependent: :destroy
  has_many :collection_job_accessories, dependent: :destroy
  has_many :collection_artifacts, dependent: :destroy

  # Crew associations
  has_many :crew_memberships, dependent: :destroy
  has_one :active_crew_membership, -> { where(retired: false) }, class_name: 'CrewMembership'
  has_one :crew, through: :active_crew_membership
  has_many :crew_invitations, dependent: :destroy
  has_many :pending_crew_invitations, -> { where(status: :pending) }, class_name: 'CrewInvitation'
  has_many :sent_crew_invitations, class_name: 'CrewInvitation', foreign_key: :invited_by_id, dependent: :nullify
  has_many :party_shares, foreign_key: :shared_by_id, dependent: :destroy

  ##### ActiveRecord Validations
  validates :username,
            presence: true,
            length: { minimum: 3, maximum: 26 }

  validates :email,
            presence: true,
            uniqueness: true,
            email: true

  validates :password,
            length: { minimum: 8 },
            presence: true,
            on: :create

  validates :password,
            length: { minimum: 8 },
            on: :update,
            if: :password_digest_changed?

  validates :password_confirmation,
            presence: true,
            on: :create

  validates :password_confirmation,
            presence: true,
            on: :update,
            if: :password_digest_changed?

  ##### ActiveModel Security
  has_secure_password

  RESET_TOKEN_EXPIRY = 1.hour
  RESET_TOKEN_COOLDOWN = 2.minutes

  ##### Enums
  # Enum for collection privacy levels (1-based to avoid JavaScript falsy 0 issues)
  enum :collection_privacy, {
    everyone: 1,
    crew_only: 2,
    private_collection: 3
  }, prefix: true

  ##### Instance Methods
  def favorite_parties
    favorites.map(&:party)
  end

  def admin?
    role == 9
  end

  def blueprint
    UserBlueprint
  end

  # Check if collection is viewable by another user
  def collection_viewable_by?(viewer)
    return true if self == viewer # Owners can always view their own collection

    case collection_privacy
    when 'everyone'
      true
    when 'crew_only'
      viewer.present? && in_same_crew_as?(viewer)
    when 'private_collection'
      false
    else
      false
    end
  end

  # Check if user is in same crew as another user
  def in_same_crew_as?(other_user)
    return false unless other_user.present?
    return false unless crew.present? && other_user.crew.present?

    crew.id == other_user.crew.id
  end

  # Get the user's crew role
  def crew_role
    active_crew_membership&.role
  end

  # Check if user is a crew officer (captain or vice captain)
  def crew_officer?
    crew_role.in?(%w[captain vice_captain])
  end

  # Check if user is a crew captain
  def crew_captain?
    crew_role == 'captain'
  end

  def generate_reset_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update_columns(
      reset_password_token_digest: Digest::SHA256.hexdigest(raw_token),
      reset_password_sent_at: Time.current
    )
    raw_token
  end

  def reset_token_valid?(raw_token)
    return false if reset_password_token_digest.blank? || reset_password_sent_at.blank?
    return false if reset_password_sent_at < RESET_TOKEN_EXPIRY.ago

    Digest::SHA256.hexdigest(raw_token) == reset_password_token_digest
  end

  def clear_reset_token!
    update_columns(
      reset_password_token_digest: nil,
      reset_password_sent_at: nil
    )
  end

  def reset_token_cooldown?
    reset_password_sent_at.present? && reset_password_sent_at > RESET_TOKEN_COOLDOWN.ago
  end
end