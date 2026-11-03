# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeaponKeySlots do
  def series(slug, trait)
    WeaponSeries.find_by(slug: slug) || create(:weapon_series, trait)
  end

  def unlocked_slots(weapon, uncap_level)
    [0, 1, 2].map { |slot| GridWeapon.key_slot_unlocked_for?(weapon, uncap_level, slot) }
  end

  describe '.key_slot_unlocked_for?' do
    it 'opens Dark Opus and Draconic skills 2 and 3 at 4★ and 5★' do
      [series('dark-opus', :opus), series('draconic', :draconic)].each do |weapon_series|
        weapon = build(:weapon, weapon_series: weapon_series)

        expect(unlocked_slots(weapon, 3).first(2)).to eq([false, false])
        expect(unlocked_slots(weapon, 4).first(2)).to eq([true, false])
        expect(unlocked_slots(weapon, 5).first(2)).to eq([true, true])
      end
    end

    it 'opens both Provenance skills at 5★' do
      weapon = build(:weapon, weapon_series: series('draconic-providence', :draconic_providence))

      expect(unlocked_slots(weapon, 4).first(2)).to eq([false, false])
      expect(unlocked_slots(weapon, 5).first(2)).to eq([true, true])
    end

    it 'opens the Destroyer anklet slot at 4★' do
      weapon = build(:weapon, weapon_series: WeaponSeries.find_by(slug: 'destroyer') ||
                                             create(:weapon_series, slug: 'destroyer'))

      expect(unlocked_slots(weapon, 3).first).to be(false)
      expect(unlocked_slots(weapon, 4).first).to be(true)
    end

    it 'gives Atma weapons only the Gauph slot and opens Gate of Omnipotence at 5★' do
      ultima = series('ultima', :ultima)

      expect(unlocked_slots(build(:weapon, weapon_series: ultima, ulb: false), 3)).to eq([true, false, false])
      expect(unlocked_slots(build(:weapon, weapon_series: ultima, ulb: true), 4)).to eq([true, true, false])
      expect(unlocked_slots(build(:weapon, weapon_series: ultima, ulb: true), 5)).to eq([true, true, true])
    end
  end

  describe 'saving a grid weapon' do
    let(:weapon) { create(:weapon, :opus, flb: true, ulb: true) }
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
    weapon = create(:weapon, :opus, flb: true, ulb: true)
    collection_weapon = build(:collection_weapon, weapon: weapon, uncap_level: 3,
                                                  weapon_key1: create(:weapon_key, :opus_key, slot: 0))

    expect(collection_weapon).not_to be_valid
    expect(collection_weapon.errors[:weapon_keys].join).to include('needs a higher uncap level')
  end
end
