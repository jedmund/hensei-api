# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261022090000_drop_character_source_columns')

RSpec.describe DropCharacterSourceColumns do
  include CharacterSourceColumns

  let(:character) { Character.without_skill_build { create(:character) } }
  let(:columns) { %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_raw_fetched_at wiki_raw_jp_fetched_at] }

  def write_column(record, column, value)
    conn = Character.connection
    conn.execute("UPDATE characters SET #{column} = #{conn.quote(value)} WHERE id = #{conn.quote(record.id)}")
  end

  def column_names = Character.connection.columns(:characters).map(&:name)

  def migrate
    output = StringIO.new
    migration = described_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  def record_copy_and_sync
    record_source_metadata('character_sources_copied_at', 2.hours.ago)
    record_source_metadata('character_sources_synced_at', 1.hour.ago, 'synced=0')
  end

  it 'drops the columns when they are empty' do
    expect(migrate).to include('columns are empty')
    expect(column_names).not_to include(*columns)
  end

  it 'drops them when every value is in sources, a newer store row included' do
    record_copy_and_sync
    Source.put(character, :wiki_raw, '{{Character}}', skip_owner_hook: true) # rewritten after the copy
    write_column(character, :wiki_raw, '{{Older column value}}')
    other = Character.without_skill_build { create(:character) }
    travel_to(3.hours.ago) { Source.put(other, :wiki_raw_jp, '<div id="body">jp</div>', skip_owner_hook: true) }
    write_column(other, :wiki_raw_jp, '<html><body><div id="body">jp</div></body></html>')

    output = migrate
    expect(output).to include('wiki_raw: 1 newer', 'wiki_raw_jp: 1 same', 'every characters source column value is in sources')
    expect(output).not_to include('Older column value')
    expect(column_names).not_to include(*columns)
  end

  it 'refuses a value that is not in sources, and drops nothing' do
    record_copy_and_sync
    write_column(character, :wiki_raw, '{{Never synced}}')

    expect { migrate }.to raise_error(described_class::UnsyncedSources, /1 characters source column values/)
    expect(column_names).to include(*columns)
  end

  it 'refuses a copied value changed after the copy' do
    record_copy_and_sync
    travel_to(3.hours.ago) { Source.put(character, :wiki_raw, '{{Copied}}', skip_owner_hook: true) }
    write_column(character, :wiki_raw, '{{Changed after the copy}}')

    expect { migrate }.to raise_error(described_class::UnsyncedSources)
  end

  it 'refuses when the columns hold data but no sync after the copy is recorded' do
    Source.put(character, :wiki_raw, '{{Character}}', skip_owner_hook: true)
    write_column(character, :wiki_raw, '{{Character}}')
    expect { migrate }.to raise_error(described_class::UnsyncedSources, /not both recorded/)

    record_source_metadata('character_sources_copied_at', 1.hour.ago)
    record_source_metadata('character_sources_synced_at', 2.hours.ago, 'synced=0')
    expect { migrate }.to raise_error(described_class::UnsyncedSources, /not both recorded/)
  end

  it 're-adds the columns, empty, on the way down' do
    migrate
    described_class.new.tap { |m| m.verbose = false }.down
    expect(column_names).to include(*columns)
  end
end
