# frozen_string_literal: true

# Which key slots a weapon copy has opened, per gbf.wiki's series pages. A slot
# belongs to a weapon skill that only appears at some level, so a key can't sit
# there below that uncap (3★ = lvl 100, 4★ = 150, 5★ = 200):
#
# - Dark Opus: Pendulums in skill 2 open at lvl 120 (4★); skill 3 (Pendulums/Chains) at 200.
# - Draconic: Four Orbs' Judgment at lvl 150 (4★); Six Dragons' Radiance at 200.
# - Draconic Provenance: forged from a lvl-200 Draconic, both skills at 200.
# - Destroyer: Anklets modify skill 3, open at lvl 150 (4★).
# - Ultima: Soulless Passage only on Ultima weapons, not their Atma stage (the
#   lvl-100 weapons without a ULB); Gate of Omnipotence at lvl 200.
#
# Lowering a copy's uncap drops the keys it locks; setting a key into a locked
# slot is a validation error. Included by GridWeapon and CollectionWeapon.
module WeaponKeySlots
  extend ActiveSupport::Concern

  # series slug => { key slot => minimum uncap level }
  MIN_UNCAP = {
    'dark-opus' => { 0 => 4, 1 => 5 },
    'draconic' => { 0 => 4, 1 => 5 },
    'draconic-providence' => { 0 => 5, 1 => 5 },
    'destroyer' => { 0 => 4 },
    'ultima' => { 2 => 5 }
  }.freeze
  # Ultima slots that Atma weapons don't have at all.
  ULTIMA_ONLY_SLOTS = [1, 2].freeze
  KEY_COLUMNS = %i[weapon_key1 weapon_key2 weapon_key3 weapon_key4].freeze

  included do
    before_validation :drop_locked_weapon_keys, if: :uncap_level_changed?
    validate :weapon_keys_in_unlocked_slots
  end

  class_methods do
    # @return [Boolean] whether a copy of weapon at uncap_level has opened key_slot
    def key_slot_unlocked_for?(weapon, uncap_level, key_slot)
      series = weapon&.weapon_series&.slug
      return false if series == 'ultima' && ULTIMA_ONLY_SLOTS.include?(key_slot) && weapon.ulb != true

      uncap_level.to_i >= MIN_UNCAP.dig(series, key_slot).to_i
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
