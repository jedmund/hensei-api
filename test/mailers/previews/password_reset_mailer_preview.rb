# frozen_string_literal: true

class PasswordResetMailerPreview < ActionMailer::Preview
  def reset_email
    user = User.first || OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'water')
    PasswordResetMailer.reset_email(user, 'preview-token-abc123')
  end

  def reset_email_wind
    user = OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'wind')
    PasswordResetMailer.reset_email(user, 'preview-token-abc123')
  end

  def reset_email_fire
    user = OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'fire')
    PasswordResetMailer.reset_email(user, 'preview-token-abc123')
  end

  def reset_email_earth
    user = OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'earth')
    PasswordResetMailer.reset_email(user, 'preview-token-abc123')
  end

  def reset_email_light
    user = OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'light')
    PasswordResetMailer.reset_email(user, 'preview-token-abc123')
  end

  def reset_email_dark
    user = OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'dark')
    PasswordResetMailer.reset_email(user, 'preview-token-abc123')
  end
end
