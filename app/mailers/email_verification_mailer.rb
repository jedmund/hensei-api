# frozen_string_literal: true

class EmailVerificationMailer < ApplicationMailer
  ELEMENT_BUTTON_COLORS = {
    'wind'  => '#1dc688',
    'fire'  => '#ec5c5c',
    'water' => '#5cb7ec',
    'earth' => '#8e3c0b',
    'light' => '#c59c0c',
    'dark'  => '#c65cec'
  }.freeze

  ELEMENT_TEXT_COLORS = {
    'wind'  => '#006a45',
    'fire'  => '#6e0000',
    'water' => '#00639c',
    'earth' => '#863504',
    'light' => '#715100',
    'dark'  => '#560075'
  }.freeze

  def verification_email(user, raw_token)
    @user = user
    @element_color = ELEMENT_BUTTON_COLORS.fetch(user.element, ELEMENT_BUTTON_COLORS['water'])
    @element_text_color = ELEMENT_TEXT_COLORS.fetch(user.element, ELEMENT_TEXT_COLORS['water'])
    frontend_url = Rails.application.credentials.dig(:app, :frontend_url) || 'http://localhost:5173'
    @verification_url = "#{frontend_url}/auth/verify-email?email=#{CGI.escape(user.email)}&token=#{raw_token}"

    mail(to: user.email, subject: 'Verify your email')
  end
end
