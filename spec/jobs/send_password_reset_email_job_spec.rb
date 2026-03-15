# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendPasswordResetEmailJob, type: :job do
  let(:user) { create(:user) }

  it 'delivers a password reset email' do
    expect {
      described_class.perform_now(user.id, 'some-token')
    }.to change { ActionMailer::Base.deliveries.count }.by(1)
  end

  it 'does nothing if the user has been deleted' do
    expect {
      described_class.perform_now('00000000-0000-0000-0000-000000000000', 'some-token')
    }.not_to change { ActionMailer::Base.deliveries.count }
  end
end
