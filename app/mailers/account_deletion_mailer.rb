# frozen_string_literal: true

class AccountDeletionMailer < ApplicationMailer
  def scheduled_email(user)
    prepare(user)
    @deletion_date = user.deletion_scheduled_at&.utc&.strftime('%B %-d, %Y')
    @login_url = "#{frontend_url}/auth/login"

    mail(to: user.email, subject: 'Your granblue.team account is scheduled for deletion')
  end

  def cancelled_email(user)
    prepare(user)
    mail(to: user.email, subject: 'Your granblue.team account deletion was cancelled')
  end

  private

  def prepare(user)
    @user = user
    @element_color = PasswordResetMailer::ELEMENT_BUTTON_COLORS.fetch(
      user.element, PasswordResetMailer::ELEMENT_BUTTON_COLORS['water']
    )
  end

  def frontend_url
    Rails.application.credentials.dig(:app, :frontend_url) || 'http://localhost:5173'
  end
end
