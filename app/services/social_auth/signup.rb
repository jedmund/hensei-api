# frozen_string_literal: true

module SocialAuth
  # Creates a user and its provider identity from a signup ticket, in one
  # transaction. The account has no password.
  #
  # The email comes from the ticket when the provider verified it (and the
  # account starts verified); otherwise the user supplies one and it goes
  # through the normal verification email.
  class Signup
    # The identity was linked to someone else after the ticket was issued (for
    # example, the same ticket used twice).
    class IdentityTaken < StandardError; end

    attr_reader :user

    def initialize(ticket, username:, email: nil)
      @ticket = ticket
      @username = username
      @email = email
    end

    # Returns true when the user was created; otherwise user.errors explains why.
    def call
      raise IdentityTaken if UserIdentity.exists?(provider: ticket['provider'], provider_uid: ticket['provider_uid'])

      build_user
      apply_display_name
      user.save
    rescue ActiveRecord::RecordNotUnique
      raise IdentityTaken
    end

    private

    attr_reader :ticket, :username, :email

    def ticket_email
      ticket['email'].presence if ticket['email_verified'] == true
    end

    def build_user
      @user = User.new(
        username: username,
        email: ticket_email || email.to_s.strip.downcase.presence,
        email_verified: ticket_email.present?
      )
      user.user_identities.build(
        provider: ticket['provider'],
        provider_uid: ticket['provider_uid'],
        email: ticket_email,
        email_verified: ticket_email.present?,
        is_private_email: ticket['is_private_email'] == true,
        last_used_at: Time.current
      )
    end

    # Apple sends the user's name only on the first sign-in. Keep it as the
    # display name when it passes the display name rules; never fail the signup
    # over it.
    def apply_display_name
      return if ticket['name'].blank?

      user.display_name = ticket['name']
      user.valid?
      user.display_name = nil if user.errors[:display_name].any?
    end
  end
end
