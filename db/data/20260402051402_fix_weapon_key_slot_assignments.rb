# frozen_string_literal: true

class FixWeaponKeySlotAssignments < ActiveRecord::Migration[7.1]
  def up
    # The import processor (WeaponProcessor#process_weapon_keys) was assigning
    # weapon keys by array index instead of the key's slot field. This caused
    # keys to land in the wrong column (e.g. a slot-0 key in weapon_key2_id).
    #
    # Additionally, inline key editing on the frontend could create duplicate
    # slot entries because validation only checked for duplicate IDs, not slots.
    #
    # This migration reassigns each key to the column matching its slot:
    #   weapon_key1_id ← key with slot 0
    #   weapon_key2_id ← key with slot 1
    #   weapon_key3_id ← key with slot 2
    #   weapon_key4_id ← key with slot 3
    #
    # When two keys share a slot (the duplicate bug), one is kept per slot.

    fixed = 0

    GridWeapon.includes(:weapon_key1, :weapon_key2, :weapon_key3, :weapon_key4)
      .where.not(weapon_key1_id: nil)
      .or(GridWeapon.where.not(weapon_key2_id: nil))
      .or(GridWeapon.where.not(weapon_key3_id: nil))
      .or(GridWeapon.where.not(weapon_key4_id: nil))
      .find_each do |gw|
        keys = [gw.weapon_key1, gw.weapon_key2, gw.weapon_key3, gw.weapon_key4].compact
        next if keys.empty?

        # Check if any key is in the wrong column
        mapping = { weapon_key1: 0, weapon_key2: 1, weapon_key3: 2, weapon_key4: 3 }
        needs_fix = mapping.any? do |assoc, expected_slot|
          key = gw.send(assoc)
          key && key.slot != expected_slot
        end
        next unless needs_fix

        # Reassign by slot, deduplicating (one key per slot)
        slot_to_key = {}
        keys.each { |key| slot_to_key[key.slot] = key.id }

        gw.update_columns(
          weapon_key1_id: slot_to_key[0],
          weapon_key2_id: slot_to_key[1],
          weapon_key3_id: slot_to_key[2],
          weapon_key4_id: slot_to_key[3]
        )
        fixed += 1
      end

    Rails.logger.info "[DATA MIGRATION] Fixed weapon key slot assignments: #{fixed} grid weapons"
  end

  def down
    # Intentionally irreversible
  end
end
