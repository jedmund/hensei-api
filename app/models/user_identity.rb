# frozen_string_literal: true

# A login provider account (Discord, Google or Apple) linked to a user, keyed on
# the provider's stable user ID. The email is kept only when the provider said
# it was verified, and is for display; it is never used to find an account.
class UserIdentity < ApplicationRecord
  PROVIDERS = %w[discord google apple].freeze

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider_uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }

  # The shape GET /users/me/identities returns for each linked provider.
  def as_api_json
    {
      provider: provider,
      email: email,
      is_private_email: is_private_email,
      created_at: created_at
    }
  end
end
