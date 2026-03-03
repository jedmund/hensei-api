# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppUpdate, type: :model do
  it 'creates a valid record' do
    record = create(:app_update)
    expect(record).to be_persisted
  end

  it 'stores update_type' do
    record = create(:app_update, update_type: 'weapons')
    expect(record.update_type).to eq('weapons')
  end

  it 'stores version when provided' do
    record = create(:app_update, :with_version)
    expect(record.version).to be_present
  end
end
