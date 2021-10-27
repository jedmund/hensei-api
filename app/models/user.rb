class User < ApplicationRecord
    before_save { self.email = email.downcase }

    ##### ActiveRecord Associations
    has_many :parties

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
end
