# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountDeletion::PurgeJob do
  it 'purges accounts whose deletion date has passed' do
    due = create(:user, deletion_scheduled_at: 1.hour.ago)
    pending = create(:user, deletion_scheduled_at: 1.day.from_now)
    kept = create(:user)

    described_class.perform_now

    expect(User.exists?(due.id)).to be(false)
    expect(User.exists?(pending.id)).to be(true)
    expect(User.exists?(kept.id)).to be(true)
  end

  it 'keeps going when one account fails' do
    failing = create(:user, deletion_scheduled_at: 2.hours.ago)
    due = create(:user, deletion_scheduled_at: 1.hour.ago)
    allow(AccountDeletion::Purge).to receive(:call).and_call_original
    allow(AccountDeletion::Purge).to receive(:call).with(failing).and_raise(ActiveRecord::RecordNotDestroyed)

    described_class.perform_now

    expect(User.exists?(failing.id)).to be(true)
    expect(User.exists?(due.id)).to be(false)
  end
end
