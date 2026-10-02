# frozen_string_literal: true

module SocialAuth
  # A verified provider identity.
  #
  # email is set only when the provider said it's verified; an unverified email
  # is dropped entirely. username_hint is what the provider calls the user, used
  # to pre-fill the username step.
  Identity = Struct.new(:provider, :uid, :email, :is_private_email, :name, :username_hint, keyword_init: true) do
    def email_verified?
      email.present?
    end

    # What a signup or link ticket carries. Never includes provider tokens.
    def ticket_payload
      {
        'provider' => provider,
        'provider_uid' => uid,
        'email' => email,
        'email_verified' => email_verified?,
        'is_private_email' => is_private_email ? true : false,
        'name' => name
      }
    end
  end
end
