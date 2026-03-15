# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PasswordResetMailer, type: :mailer do
  describe '#reset_email' do
    let(:user) { create(:user, email: 'test@example.com', username: 'skyfarmer') }
    let(:raw_token) { 'test-token-abc123' }
    let(:mail) { described_class.reset_email(user, raw_token) }

    before do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:app, :frontend_url).and_return('https://granblue.team')
    end

    it 'sends to the user email' do
      expect(mail.to).to eq(['test@example.com'])
    end

    it 'includes a reset link with the token and email' do
      expect(mail.body.encoded).to include('test-token-abc123')
      expect(mail.body.encoded).to include('test%40example.com')
      expect(mail.body.encoded).to include('https://granblue.team/auth/reset-password')
    end

    it 'addresses the user by username' do
      expect(mail.body.encoded).to include('skyfarmer')
    end
  end
end
