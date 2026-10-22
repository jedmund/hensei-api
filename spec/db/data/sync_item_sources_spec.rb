# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SyncItemSources' do
  include ActiveJob::TestHelper

  let(:migration_class) do
    require Rails.root.join('db/data/20261022120000_sync_item_sources') unless defined?(SyncItemSources)
    SyncItemSources
  end
  let(:copied_at) { 1.hour.ago.utc.change(usec: 0) }
  let!(:summon) { create(:summon) }

  def run
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  before do
    record_source_metadata(Granblue::ItemSourceSync::ITEMS_COPY_STARTED_AT_KEY, copied_at - 1.hour)
    record_source_metadata(Granblue::ItemSourceSync::ITEMS_COPIED_AT_KEY, copied_at)
    record_source_metadata(Granblue::ItemSourceSync::STORE_COPY_STARTED_AT_KEY, copied_at - 1.hour)
    record_source_metadata(Granblue::ItemSourceSync::STORE_COPIED_AT_KEY, copied_at)
  end

  it 'stores what the old code wrote after the copy, queues no builds, and records the run' do
    Summon.where(id: summon.id).update_all(wiki_raw: '{{Written after the copy}}', wiki_raw_fetched_at: Time.current)

    output = nil
    expect { output = run }.not_to have_enqueued_job
    expect(Source.read(summon, :wiki_raw)).to eq('{{Written after the copy}}')
    expect(output).to include('summons.wiki_raw: 1 checked, 0 same, 1 missing → stored')
    expect(output).not_to include('Written after the copy')
    expect(source_metadata_time(Granblue::ItemSourceSync::SYNCED_AT_KEY)).to be_within(1.minute).of(Time.current)
  end

  it 'is a no-op on a re-run' do
    Summon.where(id: summon.id).update_all(wiki_raw: '{{Page}}', wiki_raw_fetched_at: Time.current)
    run
    expect(run).to include('summons.wiki_raw: 1 checked, 1 same, 0 missing → stored')
  end
end
