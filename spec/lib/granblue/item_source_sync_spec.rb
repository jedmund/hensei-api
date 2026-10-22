# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::ItemSourceSync do
  let(:conn) { ActiveRecord::Base.connection }
  let(:copied_at) { 1.hour.ago.utc.change(usec: 0) }
  let(:fetched_at) { Time.utc(2026, 10, 15, 13, 27) }
  let(:weapon) { create(:weapon) }
  let(:summon) { create(:summon) }

  def sync = described_class.new(io: StringIO.new).call

  # The old columns, as the old code wrote them (payloads as JSON text Postgres casts to jsonb).
  def set_columns(record, **values)
    record.class.where(id: record.id).update_all(values.transform_values { |v| v.is_a?(Hash) ? JSON.generate(v) : v })
  end

  def record_copy(key, at = copied_at)
    conn.execute(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, key, at.iso8601(6)]))
      INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES (?, ?, now(), now())
      ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
    SQL
  end

  def old_row(kind, key, body, weapon_id: nil, page_kind: nil, at: fetched_at)
    conn.execute(ActiveRecord::Base.sanitize_sql([<<~SQL.squish, weapon_id, kind, key, body, Digest::SHA256.hexdigest(body), at, page_kind]))
      INSERT INTO weapon_sources (weapon_id, kind, key, body, sha256, fetched_at, page_kind, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, now(), now())
    SQL
  end

  # A row as the copy migration left it (updated before the copy time).
  def copied(owner, kind, value, **)
    travel_to(copied_at - 1.hour) { Source.put(owner, kind, value, **) }
  end

  before do
    record_copy(described_class::ITEMS_COPIED_AT_KEY)
    record_copy(described_class::STORE_COPIED_AT_KEY)
  end

  describe 'item columns' do
    it 'stores what the old code wrote after the copy, and keeps rows the store wrote since' do
      copied(weapon, :wiki_raw, '{{Copied}}')
      set_columns(weapon, wiki_raw: '{{Written later}}', wiki_raw_fetched_at: fetched_at)
      set_columns(summon, wiki_raw: '{{Missing}}', game_raw_jp: { 'name' => 'Call', 'user_id' => 1 })
      newer = create(:summon, wiki_raw: '{{Store}}')
      set_columns(newer, wiki_raw: '{{Column}}')

      results = sync

      expect(Source.read(weapon, :wiki_raw)).to eq('{{Written later}}')
      expect(weapon.reload.wiki_raw_fetched_at).to eq(fetched_at)
      expect(Source.read(summon, :wiki_raw)).to eq('{{Missing}}')
      expect(Source.read(summon, :game_raw_jp)).to eq('name' => 'Call')
      expect(Source.read(newer, :wiki_raw)).to eq('{{Store}}')
      expect(results['weapons.wiki_raw']).to have_attributes(changed: 1)
      expect(results['summons.wiki_raw']).to have_attributes(missing: 1, newer: 1)
    end

    it 'is idempotent' do
      set_columns(summon, wiki_raw: '{{Missing}}')
      sync
      expect(sync['summons.wiki_raw']).to have_attributes(same: 1, stored: 0)
    end

    it 'only fills missing rows when the copy time is unknown' do
      conn.execute("DELETE FROM ar_internal_metadata WHERE key = '#{described_class::ITEMS_COPIED_AT_KEY}'")
      copied(weapon, :wiki_raw, '{{Copied}}')
      set_columns(weapon, wiki_raw: '{{Written later}}')

      sync

      expect(Source.read(weapon, :wiki_raw)).to eq('{{Copied}}')
    end
  end

  describe 'weapon_sources' do
    it 'stores missing and changed rows, carries a later fetch over and removes deleted copies' do
      travel_to(copied_at - 1.hour) do
        WeaponSource.create!(weapon: weapon, kind: 'wiki_raw', key: 'Blade', body: 'old', fetched_at: fetched_at,
                             page_kind: 'inline')
        WeaponSource.create!(weapon: weapon, kind: 'transclusion', key: 'Gone', body: 'gone', fetched_at: fetched_at)
        WeaponSource.create!(kind: 'family_template', key: 'Template:Weapon Skills/Might', body: 'family',
                             fetched_at: fetched_at)
      end
      old_row('wiki_raw', 'Blade', 'new', weapon_id: weapon.id, page_kind: 'series_template')
      old_row('expanded', 'Blade', 'expansion', weapon_id: weapon.id, page_kind: 'series_template')
      old_row('family_template', 'Template:Weapon Skills/Might', 'family', at: fetched_at + 1.day)

      result = sync['weapon_sources']

      store = WeaponSkills::SourceStore::Database.new
      expect(store.fetch('wiki_raw', 'Blade')).to have_attributes(body: 'new', page_kind: 'series_template')
      expect(store.fetch('expanded', 'Blade').body).to eq('expansion')
      expect(store.fetch('family_template', 'Template:Weapon Skills/Might').fetched_at).to eq(fetched_at + 1.day)
      expect(store.exist?('transclusion', 'Gone')).to be(false)
      expect(result).to have_attributes(checked: 3, changed: 1, missing: 1, same: 1, removed: 1)
      expect(Source.read(weapon, :wiki_raw)).to be_nil # the weapon's own page is a column sync's business
    end

    it 'keeps a row the store wrote since the copy' do
      old_row('wiki_raw', 'Blade', 'old', weapon_id: weapon.id)
      WeaponSkills::SourceStore::Database.new.put('wiki_raw', 'Blade', 'refetched', weapon_id: weapon.id)

      expect(sync['weapon_sources']).to have_attributes(newer: 1)
      expect(WeaponSkills::SourceStore::Database.new.fetch('wiki_raw', 'Blade').body).to eq('refetched')
    end
  end

  it 'records the run and logs counts only' do
    set_columns(summon, wiki_raw: '{{Secret page}}')
    io = StringIO.new
    described_class.new(io: io).call

    expect(described_class.synced_at).to be_within(1.minute).of(Time.current)
    expect(io.string).to include('summons.wiki_raw: 1 checked')
    expect(io.string).not_to include('Secret page')
  end
end
