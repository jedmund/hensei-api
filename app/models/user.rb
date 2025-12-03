# frozen_string_literal: true

class User < ApplicationRecord
  before_save { self.email = email.downcase }

  ##### ActiveRecord Associations
  has_many :parties, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :collection_characters, dependent: :destroy
  has_many :collection_weapons, dependent: :destroy
  has_many :collection_summons, dependent: :destroy
  has_many :collection_job_accessories, dependent: :destroy
  has_many :collection_artifacts, dependent: :destroy

  # Note: The crew association will be added when crews feature is implemented
  # belongs_to :crew, optional: true

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

  ##### Enums
  # Enum for collection privacy levels
  enum :collection_privacy, {
    everyone: 0,
    crew_only: 1,
    private_collection: 2
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
      # Will be implemented when crew feature is added:
      # viewer.present? && crew.present? && viewer.crew_id == crew_id
      false # For now, crew_only acts like private until crews are implemented
    when 'private_collection'
      false
    else
      false
    end
  end

  # Helper method to check if user is in same crew (placeholder for future)
  def in_same_crew_as?(other_user)
    # Will be implemented when crew feature is added:
    # return false unless other_user.present?
    # crew.present? && other_user.crew_id == crew_id
    false
  end
end