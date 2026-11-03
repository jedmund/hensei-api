# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponKeySlots do
  let(:opus) do
    series = WeaponSeries.find_by(slug: 'dark-opus') || create(:weapon_series, :opus)
    series.update!(num_weapon_keys: 2, key_slot_min_uncaps: [4, 5])
    series
  end

  def unlocked_slots(weapon, uncap_level)
    [0, 1, 2].map { |slot| GridWeapon.key_slot_unlocked_for?(weapon, uncap_level, slot) }
  end

  describe '.key_slot_unlocked_for?' do
    it "opens each slot at its series' minimum uncap and closes slots past the count" do
      weapon = build(:weapon, weapon_series: opus)

      expect(unlocked_slots(weapon, 3)).to eq([false, false, false])
      expect(unlocked_slots(weapon, 4)).to eq([true, false, false])
      expect(unlocked_slots(weapon, 5)).to eq([true, true, false])
    end

    it "uses a variant's lower slot count (Atma: only the Gauph slot)" do
      ultima = WeaponSeries.find_by(slug: 'ultima') || create(:weapon_series, :ultima)
      ultima.update!(num_weapon_keys: 3, key_slot_min_uncaps: [0, 0, 5])
      atma = WeaponSeriesVariant.create!(weapon_series: ultima, name: 'Atma', num_weapon_keys: 1)

      expect(unlocked_slots(build(:weapon, weapon_series: ultima, weapon_series_variant: atma), 3))
        .to eq([true, false, false])
      expect(unlocked_slots(build(:weapon, weapon_series: ultima), 5)).to eq([true, true, true])
    end

    it 'leaves series without rules or a slot count unrestricted' do
      series = create(:weapon_series, slug: 'test-keys', num_weapon_keys: nil, key_slot_min_uncaps: [])

      expect(unlocked_slots(build(:weapon, weapon_series: series), 0)).to eq([true, true, true])
    end
  end

  describe 'saving a grid weapon' do
    let(:weapon) { create(:weapon, flb: true, ulb: true, weapon_series: opus) }
    let(:pendulum) { create(:weapon_key, :opus_key, slot: 0) }
    let(:chain) { create(:weapon_key, :opus_key, slot: 1) }

    it 'rejects a key in a slot the uncap has not opened' do
      grid_weapon = build(:grid_weapon, weapon: weapon, uncap_level: 4, weapon_key1: pendulum, weapon_key2: chain)

      expect(grid_weapon).not_to be_valid
      expect(grid_weapon.errors[:weapon_keys]).to include("#{chain.name_en} needs a higher uncap level")
    end

    it 'drops keys a lower uncap locks and keeps the rest' do
      grid_weapon = create(:grid_weapon, weapon: weapon, uncap_level: 5, weapon_key1: pendulum, weapon_key2: chain)

      grid_weapon.update!(uncap_level: 4)

      expect(grid_weapon.reload).to have_attributes(weapon_key1_id: pendulum.id, weapon_key2_id: nil)
    end

    it 'rejects a locked key set together with a lower uncap' do
      grid_weapon = create(:grid_weapon, weapon: weapon, uncap_level: 5, weapon_key1: pendulum)

      expect(grid_weapon.update(uncap_level: 4, weapon_key2: chain)).to be(false)
    end
  end

  it 'applies the same rules to collection weapons' do
    weapon = create(:weapon, flb: true, ulb: true, weapon_series: opus)
    collection_weapon = build(:collection_weapon, weapon: weapon, uncap_level: 3,
                                                  weapon_key1: create(:weapon_key, :opus_key, slot: 0))

    expect(collection_weapon).not_to be_valid
    expect(collection_weapon.errors[:weapon_keys].join).to include('needs a higher uncap level')
  end
end
