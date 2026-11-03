# frozen_string_literal: true

# Per key slot, the uncap level a weapon of the series needs before a key can go
# in it (index = slot). Empty means no slot is restricted. Editors set it in the
# Database; WeaponKeySlots enforces it.
class AddKeySlotMinUncapsToWeaponSeries < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_series, :key_slot_min_uncaps, :integer, array: true, default: [], null: false
  end
end
