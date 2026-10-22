# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SyncCharacterSources' do
  include CharacterSourceColumns

  include ActiveJob::TestHelper

  let(:migration_class) do
    require Rails.root.join('db/data/20261021180000_sync_character_sources') unless defined?(SyncCharacterSources)
    SyncCharacterSources
  end
  let!(:character) { Character.without_skill_build { create(:character) } }

  def write_column(value)
    Character.where(id: character.id).update_all(wiki_raw: value)
  end

  def run
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  it 'stores what the old code wrote after the copy, queues no builds, and records the run' do
    write_column('{{Written after the copy}}')

    output = nil
    expect { output = run }.not_to have_enqueued_job
    expect(Source.read(character, :wiki_raw)).to eq('{{Written after the copy}}')
    expect(output).to include('wiki_raw: 1 missing', 'characters to rebuild: 1')
    expect(output).not_to include('Written after the copy')
    expect(source_metadata_time('character_sources_synced_at')).to be_within(1.minute).of(Time.current)
  end

  it 'is a no-op on a re-run, and with nothing to do' do
    expect(run).to include('characters to rebuild: 0')

    write_column('{{Old}}')
    run
    expect { expect(run).to include('wiki_raw: 1 same', 'characters to rebuild: 0') }
      .not_to(change { Source.maximum(:updated_at) })
  end

  it 'keeps a row rewritten through the store after the copy' do
    record_source_metadata('character_sources_copied_at', 1.hour.ago)
    travel_to(2.hours.ago) { Source.put(character, :wiki_raw, '{{Copied}}', skip_owner_hook: true) }
    Source.put(character, :wiki_raw, '{{Refreshed}}', skip_owner_hook: true)
    write_column('{{Old column}}')

    expect(run).to include('wiki_raw: 1 newer')
    expect(Source.read(character, :wiki_raw)).to eq('{{Refreshed}}')
  end

  it 'replaces a copied row the old code changed afterwards' do
    record_source_metadata('character_sources_copied_at', 1.hour.ago)
    travel_to(2.hours.ago) { Source.put(character, :wiki_raw, '{{Copied}}', skip_owner_hook: true) }
    write_column('{{Changed after the copy}}')

    expect(run).to include('wiki_raw: 1 changed')
    expect(Source.read(character, :wiki_raw)).to eq('{{Changed after the copy}}')
  end

  it 'does nothing once the columns are gone' do
    %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_raw_fetched_at wiki_raw_jp_fetched_at]
      .each { |column| Character.connection.remove_column(:characters, column) }
    Character.reset_column_information

    expect(run).to include('characters source columns are gone')
  end
end
