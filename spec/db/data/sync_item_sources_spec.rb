# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SyncItemSources' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261022120000_sync_item_sources') unless defined?(SyncItemSources)
    SyncItemSources
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  it 'does nothing once the columns are dropped' do
    run
    expect(source_metadata_time('item_sources_synced_at')).to be_nil
  end

  context 'with the columns' do
    include ItemSourceColumns

    it 'records the run (the drop checks every value)' do
      run
      value = ActiveRecord::Base.connection.select_value(
        "SELECT value FROM ar_internal_metadata WHERE key = 'item_sources_synced_at'"
      )
      expect(value).to end_with('stored=0')
      expect(source_metadata_time('item_sources_synced_at')).to be_within(1.minute).of(Time.current)
    end
  end
end
