# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/siero/rateup_identity')
require Rails.root.join('db/migrate/20261002010000_add_drawable_identity_to_gacha_rateups')
require Rails.root.join('db/data/20261002010001_backfill_gacha_rateup_drawable_identity')

RSpec.describe Siero::RateupIdentity do
  let(:connection) { ActiveRecord::Base.connection }
  let(:migration) { described_class.new(connection) }

  def insert(table, values = {})
    id = SecureRandom.uuid
    values = { id: id }.merge(values)
    columns = values.keys.join(', ')
    quoted = values.values.map { |value| connection.quote(value) }.join(', ')
    connection.execute("INSERT INTO #{table} (#{columns}) VALUES (#{quoted})")
    id
  end

  def setting(gacha_id: nil, drawable_type: nil, drawable_id: nil)
    insert('gacha_rateups', gacha_id: gacha_id, drawable_type: drawable_type,
                           drawable_id: drawable_id, user_id: 'discord-123', rate: '0.25')
  end

  it 'preserves settings, reports unmappable rows and conflicts, and safely reruns after old and new writes' do
    weapon = insert('weapons')
    summon = insert('summons')
    weapon_gacha = insert('gacha', drawable_type: 'Weapon', drawable_id: weapon)
    summon_gacha = insert('gacha', drawable_type: 'Summon', drawable_id: summon)
    weapon_setting = setting(gacha_id: weapon_gacha)
    summon_setting = setting(gacha_id: summon_gacha)
    setting(gacha_id: weapon_gacha) # Preserve two different saved rows for the same identity.
    setting(gacha_id: weapon_gacha, drawable_type: 'Weapon', drawable_id: weapon)
    conflict = setting(gacha_id: weapon_gacha, drawable_type: 'Summon', drawable_id: summon)
    setting(gacha_id: SecureRandom.uuid)
    missing = setting(gacha_id: insert('gacha', drawable_type: 'Weapon', drawable_id: SecureRandom.uuid))
    setting(gacha_id: insert('gacha', drawable_type: 'Character', drawable_id: SecureRandom.uuid))
    setting(drawable_type: 'Summon', drawable_id: SecureRandom.uuid)
    before = connection.select_rows('SELECT id, gacha_id, user_id, rate, created_at FROM gacha_rateups ORDER BY id')

    report = migration.report
    expect(report).to include('backfillable' => 3, 'orphaned_gacha' => 1, 'missing_legacy_item' => 1,
                              'invalid_legacy_type' => 1, 'missing_new_item' => 1, 'conflicting_identity' => 1,
                              'duplicate_groups' => 2, 'duplicate_excess_rows' => 3)
    expect(migration.backfill['updated']).to eq(3)
    expect(connection.select_rows('SELECT id, gacha_id, user_id, rate, created_at FROM gacha_rateups ORDER BY id')).to eq(before)
    expect(connection.select_rows("SELECT drawable_type, drawable_id FROM gacha_rateups WHERE id = '#{weapon_setting}'")).to eq([['Weapon', weapon]])
    expect(connection.select_rows("SELECT drawable_type, drawable_id FROM gacha_rateups WHERE id = '#{summon_setting}'")).to eq([['Summon', summon]])
    expect(connection.select_rows("SELECT drawable_type, drawable_id FROM gacha_rateups WHERE id = '#{conflict}'")).to eq([['Summon', summon]])
    expect(connection.select_value("SELECT drawable_id FROM gacha_rateups WHERE id = '#{missing}'")).to be_nil
    snapshot = connection.select_rows('SELECT * FROM gacha_rateups ORDER BY id')
    expect(migration.backfill['updated']).to eq(0)
    expect(connection.select_rows('SELECT * FROM gacha_rateups ORDER BY id')).to eq(snapshot)

    setting(gacha_id: summon_gacha) # An old writer remains supported after the initial backfill.
    new_weapon = insert('weapons')
    setting(drawable_type: 'Weapon', drawable_id: new_weapon) # No legacy catalogue membership required.
    expect(migration.backfill['updated']).to eq(1)
    expect(migration.report).to include('new_only' => 2, 'conflicting_identity' => 1)
  end

  [['Weapon', nil], [nil, SecureRandom.uuid], ['Character', SecureRandom.uuid]].each do |type, id|
    it "rejects an invalid PostgreSQL pair #{type.inspect}/#{id.nil? ? 'null' : 'uuid'}" do
      expect do
        connection.transaction(requires_new: true) { setting(drawable_type: type, drawable_id: id) }
      end.to raise_error(ActiveRecord::StatementInvalid, /gacha_rateups_drawable_pair/)
    end
  end

  it 'reports valid new-only identities as ready without treating null legacy references as orphans' do
    setting(drawable_type: 'Weapon', drawable_id: insert('weapons'))
    setting(drawable_type: 'Summon', drawable_id: insert('summons'))
    expect(migration.report).to include('ready_for_cutover' => true, 'schema_ready' => true,
                                        'new_only' => 2, 'orphaned_gacha' => 0)
    expect(migration.backfill['updated']).to eq(0)
    expect { BackfillGachaRateupDrawableIdentity.new.up }.not_to(change { migration.report })
  end

  it 'supports read-only preflight before the additive schema is applied' do
    setting(gacha_id: SecureRandom.uuid)
    connection.transaction(requires_new: true) do
      connection.execute('ALTER TABLE gacha_rateups DROP COLUMN drawable_type, DROP COLUMN drawable_id')
      expect(migration.report).to include('schema_ready' => false, 'ready_for_cutover' => false,
                                          'rows' => 1, 'orphaned_gacha' => 1)
      expect { migration.backfill }.to raise_error(/Apply additive drawable schema/)
      AddDrawableIdentityToGachaRateups.new.up
      expect(migration.report).to include('schema_ready' => true, 'rows' => 1, 'orphaned_gacha' => 1)
      raise ActiveRecord::Rollback
    end
  end

  it 'refuses schema rollback that could lose new-only identities' do
    expect { AddDrawableIdentityToGachaRateups.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
