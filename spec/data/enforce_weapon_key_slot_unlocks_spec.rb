# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261103140100_enforce_weapon_key_slot_unlocks')

RSpec.describe EnforceWeaponKeySlotUnlocks do
  let(:opus) { WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus) }
  let(:draconic) { WeaponSeries.find_by(slug: 'draconic') || create(:weapon_series, :draconic) }
  let(:ultima) { WeaponSeries.find_by(slug: 'ultima') || create(:weapon_series, :ultima) }
  let(:pendulum) { create(:weapon_key, :opus_key, slot: 0) }
  let(:chain) { create(:weapon_key, :opus_key, slot: 1) }

  # Rows saved before the slot rules existed
  def legacy(record, **keys)
    record.update_columns(keys.transform_values(&:id).transform_keys { |k| "#{k}_id" })
    record
  end

  before do
    opus.update!(num_weapon_keys: 2)
    draconic.update!(num_weapon_keys: 1)
    ultima.update!(num_weapon_keys: 3)
  end

  it 'seeds the rules, gives Draconic two slots and Atma weapons one' do
    atma = create(:weapon, weapon_series: ultima, name_en: 'Atma Fist')

    described_class.new.up

    expect(opus.reload.key_slot_min_uncaps).to eq([4, 5])
    expect(draconic.reload).to have_attributes(num_weapon_keys: 2, key_slot_min_uncaps: [4, 5])
    expect(ultima.reload.key_slot_min_uncaps).to eq([0, 0, 5])
    expect(atma.reload.weapon_series_variant).to have_attributes(name: 'Atma', num_weapon_keys: 1)
  end

  it 'clears keys in locked slots on grid and collection weapons' do
    weapon = create(:weapon, weapon_series: opus, flb: true, ulb: true)
    grid_weapon = legacy(create(:grid_weapon, weapon: weapon, uncap_level: 4), weapon_key1: pendulum, weapon_key2: chain)
    collection_weapon = legacy(create(:collection_weapon, weapon: weapon, uncap_level: 3), weapon_key1: pendulum)
    kept = legacy(create(:grid_weapon, weapon: weapon, uncap_level: 5), weapon_key1: pendulum, weapon_key2: chain)

    described_class.new.up

    expect(grid_weapon.reload).to have_attributes(weapon_key1_id: pendulum.id, weapon_key2_id: nil)
    expect(collection_weapon.reload.weapon_key1_id).to be_nil
    expect(kept.reload).to have_attributes(weapon_key1_id: pendulum.id, weapon_key2_id: chain.id)
  end

  it "keeps a 5★ Draconic's second Teluma" do
    weapon = create(:weapon, weapon_series: draconic, flb: true, ulb: true)
    teluma = create(:weapon_key, :draconic_key, slot: 0)
    radiance = create(:weapon_key, :draconic_key, slot: 1)
    grid_weapon = legacy(create(:grid_weapon, weapon: weapon, uncap_level: 5), weapon_key1: teluma, weapon_key2: radiance)

    described_class.new.up

    expect(grid_weapon.reload.weapon_key2_id).to eq(radiance.id)
  end
end
