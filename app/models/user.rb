# frozen_string_literal: true

class User < ApplicationRecord
  before_save { self.email = email.downcase }

  ##### ActiveRecord Associations
  has_many :parties, dependent: :destroy
  has_many :favorites, dependent: :destroy

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

  def favorite_parties
    favorites.map(&:party)
  end

  def blueprint
    UserBlueprint
  end
end
