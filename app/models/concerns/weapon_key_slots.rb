# frozen_string_literal: true

# Which key slots a weapon copy has opened. A slot belongs to a weapon skill that
# only appears at some uncap, so a key can't sit there below it. The rules are
# data editors keep in the Database: the series' `key_slot_min_uncaps` (index =
# slot) and the weapon's key slot count (a variant can lower it: Atma weapons have
# only the first of Ultima's three).
#
# Lowering a copy's uncap drops the keys it locks; setting a key into a locked
# slot is a validation error. Included by GridWeapon and CollectionWeapon.
module WeaponKeySlots
  extend ActiveSupport::Concern

  KEY_COLUMNS = %i[weapon_key1 weapon_key2 weapon_key3 weapon_key4].freeze

  included do
    before_validation :drop_locked_weapon_keys, if: :uncap_level_changed?
    validate :weapon_keys_in_unlocked_slots
  end

  class_methods do
    # @return [Boolean] whether a copy of weapon at uncap_level has opened key_slot
    def key_slot_unlocked_for?(weapon, uncap_level, key_slot)
      return true if weapon.nil?

      count = weapon.effective_num_weapon_keys
      return false if count && key_slot >= count

      uncap_level.to_i >= Array(weapon.weapon_series&.key_slot_min_uncaps)[key_slot].to_i
    end
  end

  # @param key [WeaponKey]
  # @return [Boolean] whether this copy's uncap has opened the key's slot
  def key_slot_unlocked?(key)
    self.class.key_slot_unlocked_for?(weapon, uncap_level, key.slot)
  end

  private

  # A lower uncap closes slots: keys left there would be impossible in game. Keys
  # set in the same save are kept so the validation can reject them.
  def drop_locked_weapon_keys
    KEY_COLUMNS.each do |column|
      key = public_send(column)
      next if key.nil? || attribute_changed?("#{column}_id") || key_slot_unlocked?(key)

      public_send("#{column}=", nil)
    end
  end

  def weapon_keys_in_unlocked_slots
    KEY_COLUMNS.each do |column|
      key = public_send(column)
      next if key.nil? || !attribute_changed?("#{column}_id") || key_slot_unlocked?(key)

      errors.add(:weapon_keys, "#{key.name_en} needs a higher uncap level")
    end
  end
end
