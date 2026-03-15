# frozen_string_literal: true

class EmailVerificationMailerPreview < ActionMailer::Preview
  def verification_email
    user = User.first || OpenStruct.new(username: 'TestUser', email: 'test@example.com', element: 'water')
    EmailVerificationMailer.verification_email(user, 'preview-token-abc123')
  end
end
