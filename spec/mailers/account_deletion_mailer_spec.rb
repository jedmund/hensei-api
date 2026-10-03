# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountDeletionMailer do
  let(:user) { create(:user, deletion_scheduled_at: Time.utc(2026, 11, 1, 12)) }

  it 'tells the user when their account will be deleted and how to cancel' do
    mail = described_class.scheduled_email(user)

    expect(mail.to).to eq([user.email])
    expect(mail.subject).to include('scheduled for deletion')
    expect(mail.text_part.body.to_s).to include('November 1, 2026').and include('/auth/login')
    expect(mail.html_part.body.to_s).to include('Log in to cancel')
  end

  it 'confirms a cancellation' do
    mail = described_class.cancelled_email(user)

    expect(mail.to).to eq([user.email])
    expect(mail.text_part.body.to_s).to include('no longer scheduled for deletion')
  end
end
