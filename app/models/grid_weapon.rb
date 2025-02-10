# frozen_string_literal: true

##
# Model representing a grid weapon within a party.
#
# This model associates a weapon with a party and manages validations for weapon compatibility,
# conflict detection, and attribute adjustments such as determining if a weapon is mainhand.
#
# @!attribute [r] weapon
#   @return [Weapon] the associated weapon.
# @!attribute [r] party
#   @return [Party] the party to which the grid weapon belongs.
# @!attribute [r] weapon_key1
#   @return [WeaponKey, nil] the primary weapon key, if assigned.
# @!attribute [r] weapon_key2
#   @return [WeaponKey, nil] the secondary weapon key, if assigned.
# @!attribute [r] weapon_key3
#   @return [WeaponKey, nil] the tertiary weapon key, if assigned.
# @!attribute [r] weapon_key4
#   @return [WeaponKey, nil] the quaternary weapon key, if assigned.
# @!attribute [r] awakening
#   @return [Awakening, nil] the associated awakening, if any.
class GridWeapon < ApplicationRecord
  # Allowed extra positions and allowed weapon series when in an extra position.
  EXTRA_POSITIONS = [9, 10, 11].freeze
  ALLOWED_EXTRA_SERIES = [11, 16, 17, 28, 29, 32, 34].freeze

  belongs_to :weapon, foreign_key: :weapon_id, primary_key: :id

  belongs_to :party,
             counter_cache: :weapons_count,
             inverse_of: :weapons
  validates_presence_of :party

  belongs_to :weapon_key1, class_name: 'WeaponKey', foreign_key: :weapon_key1_id, optional: true
  belongs_to :weapon_key2, class_name: 'WeaponKey', foreign_key: :weapon_key2_id, optional: true
  belongs_to :weapon_key3, class_name: 'WeaponKey', foreign_key: :weapon_key3_id, optional: true
  belongs_to :weapon_key4, class_name: 'WeaponKey', foreign_key: :weapon_key4_id, optional: true

  belongs_to :awakening, optional: true

  validate :compatible_with_position, on: :create
  validate :no_conflicts, on: :create

  before_save :assign_mainhand

  ##### Amoeba configuration
  amoeba do
    nullify :ax_modifier1
    nullify :ax_modifier2
    nullify :ax_strength1
    nullify :ax_strength2
  end

  ##
  # Returns the blueprint for rendering the grid weapon.
  #
  # @return [GridWeaponBlueprint] the blueprint class for grid weapons.
  def blueprint
    GridWeaponBlueprint
  end

  ##
  # Returns an array of assigned weapon keys.
  #
  # This method returns an array containing weapon_key1, weapon_key2, and weapon_key3,
  # omitting any nil values.
  #
  # @return [Array<WeaponKey>] the non-nil weapon keys.
  def weapon_keys
    [weapon_key1, weapon_key2, weapon_key3].compact
  end

  ##
  # Returns conflicting grid weapons within a given party.
  #
  # Checks if the associated weapon is present, responds to a :limit method, and is limited.
  # It then iterates over the party's grid weapons and selects those that conflict with this one,
  # based on series matching or specific conditions related to opus or draconic status.
  #
  # @param party [Party] the party in which to check for conflicts.
  # @return [ActiveRecord::Relation<GridWeapon>] an array of conflicting grid weapons (empty if none are found).
  def conflicts(party)
    return [] unless weapon.present? && weapon.respond_to?(:limit) && weapon.limit

    party.weapons.select do |party_weapon|
      # Skip if the record is not persisted.
      next false unless party_weapon.id.present?

      id_match = weapon.id == party_weapon.id
      series_match = weapon.series == party_weapon.weapon.series
      both_opus_or_draconic = weapon.opus_or_draconic? && party_weapon.weapon.opus_or_draconic?
      both_draconic = weapon.draconic_or_providence? && party_weapon.weapon.draconic_or_providence?

      (series_match || both_opus_or_draconic || both_draconic) && !id_match
    end
  end

  private

  ##
  # Validates whether the grid weapon is compatible with the desired position.
  #
  # For positions 9, 10, or 11 (considered extra positions), the weapon's series must belong to the allowed set.
  # If the weapon is in an extra position but does not match an allowed series, an error is added.
  #
  # @return [void]
  def compatible_with_position
    return unless weapon.present?

    if EXTRA_POSITIONS.include?(position.to_i) && !ALLOWED_EXTRA_SERIES.include?(weapon.series.to_i)
      errors.add(:series, 'must be compatible with position')
    end
  end

  ##
  # Validates that the assigned weapon keys are compatible with the weapon.
  #
  # Iterates over each non-nil weapon key and checks compatibility using the weapon's
  # `compatible_with_key?` method. An error is added for any key that is not compatible.
  #
  # @return [void]
  def compatible_with_key
    weapon_keys.each do |key|
      errors.add(:weapon_keys, 'must be compatible with weapon') unless weapon.compatible_with_key?(key)
    end
  end

  ##
  # Validates that there are no conflicting grid weapons in the party.
  #
  # Checks if the current grid weapon conflicts with any other grid weapons within the party.
  # If conflicting weapons are found, an error is added.
  #
  # @return [void]
  def no_conflicts
    conflicting = conflicts(party)
    errors.add(:series, 'must not conflict with existing weapons') if conflicting.any?
  end

  ##
  # Determines if the grid weapon should be marked as mainhand based on its position.
  #
  # If the grid weapon's position is -1, sets the `mainhand` attribute to true.
  #
  # @return [void]
  def assign_mainhand
    self.mainhand = (position == -1)
  end
end
