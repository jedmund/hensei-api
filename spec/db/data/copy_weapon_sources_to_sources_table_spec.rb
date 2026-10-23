# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CopyWeaponSourcesToSourcesTable' do
  include ItemSourceColumns

  let(:migration_class) do
    unless defined?(CopyWeaponSourcesToSourcesTable)
      require Rails.root.join('db/data/20261022110100_copy_weapon_sources_to_sources_table')
    end
    CopyWeaponSourcesToSourcesTable
  end
  let(:fetched_at) { Time.utc(2026, 10, 15, 13, 27) }
  let(:weapon) { create(:weapon) }

  # A row as the old code left it in weapon_sources (WeaponSource reads `sources` now).
  def old_row(kind, key, body, weapon_id: nil, page_kind: nil)
    conn = ActiveRecord::Base.connection
    conn.execute(<<~SQL.squish)
      INSERT INTO weapon_sources (weapon_id, kind, key, body, sha256, fetched_at, page_kind, created_at, updated_at)
      VALUES (#{conn.quote(weapon_id)}, #{conn.quote(kind)}, #{conn.quote(key)}, #{conn.quote(body)},
              #{conn.quote(Digest::SHA256.hexdigest(body))}, #{conn.quote(fetched_at)}, #{conn.quote(page_kind)},
              #{conn.quote(fetched_at)}, #{conn.quote(fetched_at)})
    SQL
  end

  def run
    migration_class.new.tap { |m| m.verbose = false }.up
  end

  before do
    old_row('wiki_raw', 'Blade', '{{Weapon}}', weapon_id: weapon.id, page_kind: 'series_template')
    old_row('expanded', 'Blade', 'expanded', weapon_id: weapon.id, page_kind: 'series_template')
    old_row('transclusion', 'Template:Weapon/Common/Six', '{{template}}', weapon_id: weapon.id)
    old_row('family_template', 'Template:Weapon Skills/Might', 'family')
    old_row('wiki_raw', 'Ultima Weapon/Series', 'series page')
  end

  it 'copies every row verbatim, owned by its weapon or shared' do
    run

    expect(WeaponSource.pluck(:weapon_id, :kind, :key, :body, :sha256, :page_kind, :fetched_at)).to contain_exactly(
      [weapon.id, 'wiki_raw', 'Blade', '{{Weapon}}', Digest::SHA256.hexdigest('{{Weapon}}'), 'series_template', fetched_at],
      [weapon.id, 'expanded', 'Blade', 'expanded', Digest::SHA256.hexdigest('expanded'), 'series_template', fetched_at],
      [weapon.id, 'transclusion', 'Template:Weapon/Common/Six', '{{template}}', Digest::SHA256.hexdigest('{{template}}'),
       nil, fetched_at],
      [nil, 'family_template', 'Template:Weapon Skills/Might', 'family', Digest::SHA256.hexdigest('family'), nil, fetched_at],
      [nil, 'wiki_raw', 'Ultima Weapon/Series', 'series page', Digest::SHA256.hexdigest('series page'), nil, fetched_at]
    )
    expect(Source.where(owner_type: 'Weapon').count).to eq(3)
    expect(WeaponSkills::SourceStore::Database.new.fetch('expanded', 'Blade').page_kind).to eq('series_template')
  end

  it "makes the copied page the weapon's wiki_raw" do
    run
    expect(weapon.reload.wiki_raw).to eq('{{Weapon}}')
  end

  it 'is idempotent and keeps a row already written through the store' do
    WeaponSkills::SourceStore::Database.new.put('wiki_raw', 'Blade', '{{Newer}}', weapon_id: weapon.id)
    run
    run

    expect(WeaponSource.count).to eq(5)
    expect(WeaponSkills::SourceStore::Database.new.fetch('wiki_raw', 'Blade').body).to eq('{{Newer}}')
  end

  it 'copies in batches past the first' do
    stub_const("#{migration_class}::BATCH", 2)
    run
    expect(WeaponSource.count).to eq(5)
  end

  it 'records when it first ran' do
    run
    first = ActiveRecord::Base.connection.select_value(
      "SELECT value FROM ar_internal_metadata WHERE key = 'weapon_sources_copied_at'"
    )
    expect(Time.iso8601(first)).to be_within(1.minute).of(Time.current)
  end

  it 'is irreversible' do
    expect { migration_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end

  it 'logs counts only' do
    output = StringIO.new
    migration = migration_class.new
    allow(migration).to receive(:write) { |text| output.puts(text) }
    migration.up
    migration.up

    expect(output.string).to include('wiki_raw: 2 copied, 0 already in sources', 'wiki_raw: 0 copied, 2 already in sources')
    expect(output.string).not_to include('{{Weapon}}', 'series page', 'Blade')
  end
end
