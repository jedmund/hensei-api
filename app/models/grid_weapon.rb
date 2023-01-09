# frozen_string_literal: true

class GridWeapon < ApplicationRecord
  belongs_to :party,
             counter_cache: :weapons_count,
             inverse_of: :weapons
  validates_presence_of :party

  belongs_to :weapon_key1, class_name: 'WeaponKey', foreign_key: :weapon_key1_id, optional: true
  belongs_to :weapon_key2, class_name: 'WeaponKey', foreign_key: :weapon_key2_id, optional: true
  belongs_to :weapon_key3, class_name: 'WeaponKey', foreign_key: :weapon_key3_id, optional: true

  validate :compatible_with_position, on: :create
  validate :no_conflicts, on: :create

  ##### Amoeba configuration
  amoeba do
    nullify :ax_modifier1
    nullify :ax_modifier2
    nullify :ax_strength1
    nullify :ax_strength2
  end

  # Helper methods
  def blueprint
    GridWeaponBlueprint
  end

  def weapon
    Weapon.find(weapon_id)
  end

  def weapon_keys
    [weapon_key1, weapon_key2, weapon_key3].compact
  end

  # Returns conflicting weapons if they exist
  def conflicts(party)
    return unless weapon.limit

    party.weapons.find do |party_weapon|
      return unless party_weapon.id

      id_match = weapon.id == party_weapon.id
      series_match = weapon.series == party_weapon.weapon.series
      both_opus_or_draconic = weapon.opus_or_draconic? && party_weapon.weapon.opus_or_draconic?
      weapon if (series_match || both_opus_or_draconic) && !id_match
    end
  end

  private

  # Conflict management methods

  # Validates whether the weapon can be added to the desired position
  def compatible_with_position
    return unless [9, 10, 11].include?(position.to_i) && ![11, 16, 17, 28, 29].include?(weapon.series)

    errors.add(:series, 'must be compatible with position')
  end

  # Validates whether the desired weapon key can be added to the weapon
  def compatible_with_key
    weapon_keys.each do |key|
      errors.add(:weapon_keys, 'must be compatible with weapon') unless weapon.compatible_with_key?(key)
    end
  end

  # Validates whether there is a conflict with the party
  def no_conflicts
    # Check if the grid weapon conflicts with any of the other grid weapons in the party
    errors.add(:series, 'must not conflict with existing weapons') unless conflicts(party).nil?
  end
end
