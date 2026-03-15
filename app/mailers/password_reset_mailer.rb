# frozen_string_literal: true

class PasswordResetMailer < ApplicationMailer
  def reset_email(user, raw_token)
    @user = user
    frontend_url = Rails.application.credentials.dig(:app, :frontend_url) || 'http://localhost:5173'
    @reset_url = "#{frontend_url}/auth/reset-password?email=#{CGI.escape(user.email)}&token=#{raw_token}"

    mail(to: user.email, subject: 'Reset your password')
  end
end
