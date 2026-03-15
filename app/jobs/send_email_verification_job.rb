# frozen_string_literal: true

class SendEmailVerificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, raw_token)
    user = User.find_by(id: user_id)
    return unless user

    EmailVerificationMailer.verification_email(user, raw_token).deliver_now
  end
end
