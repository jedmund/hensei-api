# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::ScheduleSyncJob do
  it 'is a stub that logs and returns nil' do
    allow(Rails.logger).to receive(:info)
    expect(described_class.perform_now).to be_nil
    expect(Rails.logger).to have_received(:info).with(/ScheduleSyncJob/)
  end
end
