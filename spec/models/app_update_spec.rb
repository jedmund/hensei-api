# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppUpdate, type: :model do
  it 'creates a valid record with default update_type' do
    record = create(:app_update)
    expect(record).to be_persisted
    expect(record.update_type).to eq('characters')
  end

  it 'stores different update_types' do
    record = create(:app_update, update_type: 'weapons')
    expect(record.update_type).to eq('weapons')
    expect(record.reload.update_type).to eq('weapons')
  end

  it 'stores version when provided' do
    record = create(:app_update, :with_version)
    expect(record.version).to eq('2.0')
    expect(record.version).to be_present
  end

  it 'uses updated_at as primary key' do
    record = create(:app_update)
    expect(record.class.primary_key).to eq('updated_at')
    expect(record.updated_at).to be_present
  end
end
