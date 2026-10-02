# frozen_string_literal: true

class User < ApplicationRecord
  before_save { self.email = email&.downcase }

  ##### ActiveRecord Associations
  has_many :parties, dependent: :destroy
  has_many :playlists, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :collection_characters, dependent: :destroy
  has_many :collection_weapons, dependent: :destroy
  has_many :collection_summons, dependent: :destroy
  has_many :collection_job_accessories, dependent: :destroy
  has_many :collection_artifacts, dependent: :destroy
  has_many :support_summons, dependent: :destroy

  # Crew associations
  has_many :crew_memberships, dependent: :destroy
  has_one :active_crew_membership, -> { where(retired: false) }, class_name: 'CrewMembership'
  has_one :crew, through: :active_crew_membership
  has_many :crew_invitations, dependent: :destroy
  has_many :pending_crew_invitations, -> { where(status: :pending) }, class_name: 'CrewInvitation'
  has_many :sent_crew_invitations, class_name: 'CrewInvitation', foreign_key: :invited_by_id, dependent: :nullify
  has_many :party_shares, foreign_key: :shared_by_id, dependent: :destroy
  has_many :user_edit_keys, dependent: :destroy
  has_many :user_identities, dependent: :destroy
  has_many :extension_auth_codes, dependent: :delete_all

  ##### ActiveRecord Validations
  USERNAME_FORMAT = /\A[a-zA-Z0-9_-]+\z/

  validates :username,
            presence: true,
            length: { minimum: 3, maximum: 26 },
            uniqueness: { case_sensitive: false }

  validates :username,
            format: { with: USERNAME_FORMAT, message: 'can only contain letters, numbers, underscores, and hyphens' },
            profanity: { languages: [:en], tier: :strict, reserved: true, message: 'is not available' },
            if: :should_validate_username_format?

  validates :display_name,
            length: { minimum: 3, maximum: 26 },
            profanity: { languages: [:en, :ja], tier: :strict, message: 'contains inappropriate language' },
            allow_nil: true,
            allow_blank: true

  validates :description,
            length: { maximum: 140 },
            profanity: { languages: [:en, :ja], tier: :strict, message: 'contains inappropriate language' },
            allow_nil: true,
            allow_blank: true

  validates :email,
            presence: true,
            uniqueness: true,
            email: true

  # Password validations. has_secure_password's own validations are off so that
  # accounts created with a login provider can exist without a password; these
  # replace them. A password signup is validated exactly as before, and a
  # password is validated whenever one is being set.
  validates :password,
            length: { minimum: 8 },
            presence: true,
            on: :create,
            unless: :provider_signup?

  validates :password,
            length: { minimum: 8 },
            on: :update,
            if: :password_digest_changed?

  validates :password,
            length: { minimum: 8 },
            on: :create,
            if: :provider_signup_with_password?

  validates :password_confirmation,
            presence: true,
            on: :create,
            unless: :provider_signup?

  validates :password_confirmation,
            presence: true,
            on: :update,
            if: :password_digest_changed?

  validates :password_confirmation,
            presence: true,
            on: :create,
            if: :provider_signup_with_password?

  validates :password, confirmation: true, allow_nil: true
  validate :password_digest_presence
  validate :password_within_bcrypt_limit

  ##### ActiveModel Security
  has_secure_password validations: false

  RESET_TOKEN_EXPIRY = 1.hour
  RESET_TOKEN_COOLDOWN = 2.minutes
  VERIFICATION_TOKEN_EXPIRY = 24.hours
  VERIFICATION_TOKEN_COOLDOWN = 2.minutes

  ##### Enums
  # Enum for collection privacy levels (1-based to avoid JavaScript falsy 0 issues)
  enum :collection_privacy, {
    everyone: 1,
    crew_only: 2,
    private_collection: 3
  }, prefix: true

  ##### Callbacks
  before_validation :set_username_migrated, on: :create
  before_save :mark_username_migrated, if: :username_changed?

  ##### Instance Methods
  def display_name_or_username
    display_name.presence || username
  end

  def favorite_parties
    favorites.map(&:party)
  end

  def admin?
    role == 9
  end

  def editor?
    role.to_i >= 7
  end

  def blueprint
    UserBlueprint
  end

  def password?
    password_digest.present?
  end

  # The user summary returned alongside OAuth tokens (POST /oauth/token and
  # social sign-in).
  def token_payload
    { id: id, username: username, role: role }
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

  # Check if support summons are viewable by another user.
  # Owners can always view their own; otherwise gated by a single public/private toggle.
  def support_summons_viewable_by?(viewer)
    return true if self == viewer

    support_summons_public
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

  def generate_verification_token!
    raw_token = SecureRandom.urlsafe_base64(32)
    update_columns(
      email_verification_token_digest: Digest::SHA256.hexdigest(raw_token),
      email_verification_sent_at: Time.current
    )
    raw_token
  end

  def verification_token_valid?(raw_token)
    return false if email_verification_token_digest.blank? || email_verification_sent_at.blank?
    return false if email_verification_sent_at < VERIFICATION_TOKEN_EXPIRY.ago

    Digest::SHA256.hexdigest(raw_token) == email_verification_token_digest
  end

  def verify_email!
    update_columns(
      email_verified: true,
      email_verification_token_digest: nil,
      email_verification_sent_at: nil
    )
  end

  def verification_token_cooldown?
    email_verification_sent_at.present? && email_verification_sent_at > VERIFICATION_TOKEN_COOLDOWN.ago
  end

  private

  # A new account created with a login provider: it has an identity to log in
  # with, so it doesn't need a password.
  def provider_signup?
    new_record? && user_identities.any?
  end

  def provider_signup_with_password?
    provider_signup? && password_digest.present?
  end

  # Mirrors has_secure_password's presence check: a password signup needs a
  # password, and an account that has a password can't have it removed.
  def password_digest_presence
    return if password_digest.present?

    if new_record?
      errors.add(:password, :blank) unless provider_signup?
    elsif password_digest_was.present?
      errors.add(:password, :blank)
    end
  end

  def password_within_bcrypt_limit
    return if password.blank?
    return if password.bytesize <= ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

    errors.add(:password, :password_too_long)
  end

  def should_validate_username_format?
    username_migrated? || username_changed?
  end

  def set_username_migrated
    self.username_migrated = true
  end

  def mark_username_migrated
    self.username_migrated = true
  end
end