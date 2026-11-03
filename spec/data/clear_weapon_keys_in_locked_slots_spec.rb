# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261103130000_clear_weapon_keys_in_locked_slots')

RSpec.describe ClearWeaponKeysInLockedSlots do
  let(:weapon) { create(:weapon, :opus, flb: true, ulb: true) }
  let(:pendulum) { create(:weapon_key, :opus_key, slot: 0) }
  let(:chain) { create(:weapon_key, :opus_key, slot: 1) }

  # Legacy rows were saved before the slot rules existed.
  def legacy(record, **keys)
    record.update_columns(keys.transform_values(&:id).transform_keys { |k| "#{k}_id" })
    record
  end

  it 'clears keys in locked slots on grid and collection weapons' do
    grid_weapon = legacy(create(:grid_weapon, weapon: weapon, uncap_level: 4), weapon_key1: pendulum, weapon_key2: chain)
    collection_weapon = legacy(create(:collection_weapon, weapon: weapon, uncap_level: 3), weapon_key1: pendulum)
    kept = legacy(create(:grid_weapon, weapon: weapon, uncap_level: 5), weapon_key1: pendulum, weapon_key2: chain)

    described_class.new.up

    expect(grid_weapon.reload).to have_attributes(weapon_key1_id: pendulum.id, weapon_key2_id: nil)
    expect(collection_weapon.reload.weapon_key1_id).to be_nil
    expect(kept.reload).to have_attributes(weapon_key1_id: pendulum.id, weapon_key2_id: chain.id)
  end
end
