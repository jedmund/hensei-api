# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261023100000_drop_item_source_columns')

RSpec.describe DropItemSourceColumns do
  include ItemSourceColumns

  let(:weapon) { create(:weapon, wiki_en: 'Blade') }
  let(:summon) { create(:summon) }
  let(:columns) { %w[wiki_raw wiki_raw_jp game_raw_en game_raw_jp wiki_raw_fetched_at wiki_raw_jp_fetched_at] }
  let(:conn) { ActiveRecord::Base.connection }

  def write_column(record, column, value)
    conn.execute("UPDATE #{record.class.table_name} SET #{column} = #{conn.quote(value)} WHERE id = #{conn.quote(record.id)}")
  end

  def old_row(kind, key, body, weapon_id: weapon.id)
    conn.execute(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, weapon_id, kind, key, body, Digest::SHA256.hexdigest(body)]))
      INSERT INTO weapon_sources (weapon_id, kind, key, body, sha256, fetched_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, now() - interval '3 hours', now() - interval '3 hours', now() - interval '3 hours')
    SQL
  end

  def column_names(table) = conn.columns(table).map(&:name)

  def migrate
    output = StringIO.new
    migration = described_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    output.string
  end

  def record_copies_and_sync(sync_suffix = 'stored=0')
    record_source_metadata('item_sources_copied_at', 2.hours.ago)
    record_source_metadata('weapon_sources_copied_at', 2.hours.ago)
    record_source_metadata('item_sources_synced_at', 1.hour.ago, sync_suffix)
  end

  # A row as the copy left it (before the copy time).
  def copied(&) = travel_to(150.minutes.ago, &)

  def dropped?
    !column_names(:weapons).intersect?(columns) && !column_names(:summons).intersect?(columns) &&
      !conn.table_exists?(:weapon_sources)
  end

  it 'drops the columns and weapon_sources when they are empty' do
    expect(migrate).to include('are empty; nothing to check')
    expect(dropped?).to be(true)
  end

  it 'drops them when every value and stored page is in sources' do
    record_copies_and_sync
    copied do
      Source.put(summon, :wiki_raw, '{{Summon}}')
      WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: '{{Weapon}}', fetched_at: Time.current)
    end
    write_column(summon, :wiki_raw, '{{Summon}}')
    old_row('wiki_raw', 'Blade', '{{Weapon}}')

    output = migrate
    expect(output).to include('summons.wiki_raw: 1 same', 'weapon_sources: 1 same', 'every weapons/summons source value')
    expect(output).not_to include('{{Summon}}', '{{Weapon}}')
    expect(dropped?).to be(true)
  end

  it 'refuses a column value that is not in sources, and drops nothing' do
    record_copies_and_sync
    write_column(summon, :wiki_raw, '{{Never synced}}')
    write_column(summon, :wiki_raw_fetched_at, 30.minutes.ago)

    expect { migrate }.to raise_error(described_class::UnsyncedSources, %r{1 weapon/summon source values})
    expect(column_names(:summons)).to include(*columns)
    expect(conn.table_exists?(:weapon_sources)).to be(true)
  end

  it 'refuses a weapon_sources row that is not in sources' do
    record_copies_and_sync
    old_row('transclusion', 'Template:Weapon/Common/Six', '{{template}}')
    conn.execute('UPDATE weapon_sources SET updated_at = now()') # written by the old code after the copy

    expect { migrate }.to raise_error(described_class::UnsyncedSources)
    expect(conn.table_exists?(:weapon_sources)).to be(true)
  end

  it 'refuses when the sync is missing, older than a copy, or skipped part of its work' do
    write_column(summon, :wiki_raw, '{{Summon}}')
    expect { migrate }.to raise_error(described_class::UnsyncedSources, /not all recorded/)

    record_source_metadata('item_sources_copied_at', 1.hour.ago)
    record_source_metadata('weapon_sources_copied_at', 1.hour.ago)
    record_source_metadata('item_sources_synced_at', 2.hours.ago, 'stored=0')
    expect { migrate }.to raise_error(described_class::UnsyncedSources, /not all recorded/)

    record_copies_and_sync('stored=0 skipped=items')
    expect { migrate }.to raise_error(described_class::UnsyncedSources, /skipped part of its work/)
  end

  it 're-adds the columns and weapon_sources, empty, on the way down' do
    migrate
    described_class.new.tap { |m| m.verbose = false }.down
    expect(column_names(:weapons)).to include(*columns)
    expect(conn.table_exists?(:weapon_sources)).to be(true)
  end
end
