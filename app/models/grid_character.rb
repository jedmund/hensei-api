# frozen_string_literal: true

##
# This file defines the GridCharacter model which represents a character's grid configuration within a party.
# The GridCharacter model handles validations related to awakenings, rings, mastery values, and transcendence.
# It includes virtual attributes for processing new rings and awakening data, and utilizes the amoeba gem
# for duplicating records with specific attribute resets.
#
# @note This model belongs to a Character, an optional Awakening, and a Party. It maintains associations for
#   these relationships and includes counter caches for performance optimization.
#
# @!attribute [r] character
#   @return [Character] the associated character record.
# @!attribute [r] awakening
#   @return [Awakening, nil] the associated awakening record (optional).
# @!attribute [r] party
#   @return [Party] the associated party record.
#
class GridCharacter < ApplicationRecord
  # Associations
  belongs_to :character, foreign_key: :character_id, primary_key: :id
  belongs_to :awakening, optional: true
  belongs_to :party,
             counter_cache: :characters_count,
             inverse_of: :characters

  # Validations
  validates_presence_of :party

  # Validate that uncap_level and transcendence_step are present and numeric.
  validates :uncap_level, presence: true, numericality: { only_integer: true }
  validates :transcendence_step, presence: true, numericality: { only_integer: true }
  
  validate :validate_awakening_level, on: :update
  validate :transcendence, on: :update
  validate :validate_over_mastery_values, on: :update
  validate :validate_aetherial_mastery_value, on: :update

  # Virtual attributes
  attr_accessor :new_rings
  attr_accessor :new_awakening

  ##### Amoeba configuration
  amoeba do
    set ring1: { modifier: nil, strength: nil }
    set ring2: { modifier: nil, strength: nil }
    set ring3: { modifier: nil, strength: nil }
    set ring4: { modifier: nil, strength: nil }
    set earring: { modifier: nil, strength: nil }
    set perpetuity: false
  end

  # Hooks
  before_validation :apply_new_rings, if: -> { new_rings.present? }
  before_validation :apply_new_awakening, if: -> { new_awakening.present? }
  before_save :add_awakening

  ##
  # Validates the awakening level to ensure it falls within the allowed range.
  #
  # @note Triggered on update.
  # @return [void]
  def validate_awakening_level
    errors.add(:awakening, 'awakening level too low') if awakening_level < 1
    errors.add(:awakening, 'awakening level too high') if awakening_level > 9
  end

  ##
  # Validates the transcendence step of the character.
  #
  # Ensures that the transcendence step is appropriate based on the character's ULB status.
  # Adds errors if:
  # - The character has a positive transcendence_step but no transcendence (ulb is false).
  # - The transcendence_step exceeds the allowed maximum.
  # - The transcendence_step is negative when character.ulb is true.
  #
  # @note Triggered on update.
  # @return [void]
  def transcendence
    errors.add(:transcendence_step, 'character has no transcendence') if transcendence_step.positive? && !character.ulb
    errors.add(:transcendence_step, 'transcendence step too high') if transcendence_step > 5 && character.ulb
    errors.add(:transcendence_step, 'transcendence step too low') if transcendence_step.negative? && character.ulb
  end

  ##
  # Validates the over mastery attack value for ring1.
  #
  # Checks that if ring1's modifier is set, the strength must be one of the allowed attack values.
  # Adds an error if the value is not valid.
  #
  # @return [void]
  def over_mastery_attack
    errors.add(:ring1, 'invalid value') unless ring1['modifier'].nil? || atk_values.include?(ring1['strength'])
  end

  ##
  # Validates the over mastery HP value for ring2.
  #
  # If ring2's modifier is present, ensures that the strength is within the allowed HP values.
  # Adds an error if the value is not valid.
  #
  # @return [void]
  def over_mastery_hp
    return if ring2['modifier'].nil?

    errors.add(:ring2, 'invalid value') unless hp_values.include?(ring2['strength'])
  end

  ##
  # Validates over mastery values by invoking individual and cross-field validations.
  #
  # This method triggers:
  # - Validation for individual over mastery values for rings 1-4.
  # - Validation ensuring that ring1's attack and ring2's HP values are consistent.
  #
  # @return [void]
  def validate_over_mastery_values
    validate_individual_over_mastery_values
    validate_over_mastery_attack_matches_hp
  end

  ##
  # Validates individual over mastery values for each ring (ring1 to ring4).
  #
  # Iterates over each ring and, if a modifier is present, uses a helper to verify that the associated strength
  # is within the permitted range based on over mastery rules.
  #
  # @return [void]
  def validate_individual_over_mastery_values
    # Iterate over rings 1-4 and check each ring’s value.
    [ring1, ring2, ring3, ring4].each_with_index do |ring, index|
      next if ring['modifier'].nil?
      modifier = over_mastery_modifiers[ring['modifier']]
      # Use a helper to add errors if the value is out-of-range.
      check_value({ "ring#{index}": { ring[modifier] => ring['strength'] } }, 'over_mastery')
    end
  end

  ##
  # Validates that the over mastery attack value matches the HP value appropriately.
  #
  # Converts ring1 and ring2 hashes to use indifferent access, and if either ring has a modifier set,
  # checks that ring2's strength is exactly half of ring1's strength.
  # Adds an error if the values do not match.
  #
  # @return [void]
  def validate_over_mastery_attack_matches_hp
    # Convert ring1 and ring2 to use indifferent access so that keys (symbols or strings)
    # can be accessed uniformly.
    r1 = ring1.with_indifferent_access
    r2 = ring2.with_indifferent_access
    # Only check if either ring has a modifier set.
    if r1[:modifier].present? || r2[:modifier].present?
      # Ensure that ring2's strength equals exactly half of ring1's strength.
      unless r2[:strength].to_f == (r1[:strength].to_f / 2)
        errors.add(:over_mastery, 'over mastery attack and hp values do not match')
      end
    end
  end

  ##
  # Validates the aetherial mastery value for the earring.
  #
  # If the earring's modifier is present and positive, it uses a helper method to check that the strength
  # falls within the allowed range for aetherial mastery.
  #
  # @return [void]
  def validate_aetherial_mastery_value
    return if earring['modifier'].nil?

    return unless earring['modifier'].positive?

    modifier = aetherial_mastery_modifiers[earring['modifier']].to_sym
    check_value({ "earring": { modifier => earring['strength'] } },
                'aetherial_mastery')
  end

  ##
  # Returns the blueprint for rendering the grid character.
  #
  # @return [GridCharacterBlueprint] the blueprint class used for grid character representation.
  def blueprint
    GridCharacterBlueprint
  end

  private

  ##
  # Adds a default awakening to the character before saving if none is set.
  #
  # Retrieves the Awakening record with slug 'character-balanced' and assigns it.
  #
  # @return [void]
  def add_awakening
    return unless awakening.nil?

    self.awakening = Awakening.where(slug: 'character-balanced').sole
  end

  ##
  # Applies new ring configurations from the virtual attribute +new_rings+.
  #
  # Expects +new_rings+ to be an array of hashes with keys "modifier" and "strength".
  # Pads the array with default ring hashes to ensure there are exactly four rings, then assigns them to
  # ring1, ring2, ring3, and ring4.
  #
  # @return [void]
  def apply_new_rings
    # Expect new_rings to be an array of hashes, e.g.,
    # [{"modifier" => "1", "strength" => "1500"}, {"modifier" => "2", "strength" => "750"}]
    default_ring = { 'modifier' => nil, 'strength' => nil }
    rings_array = Array(new_rings).map(&:to_h)
    # Pad with defaults so there are exactly four rings
    rings_array.fill(default_ring, rings_array.size...4)
    self.ring1 = rings_array[0]
    self.ring2 = rings_array[1]
    self.ring3 = rings_array[2]
    self.ring4 = rings_array[3]
  end

  ##
  # Applies new awakening configuration from the virtual attribute +new_awakening+.
  #
  # Sets the +awakening_id+ and +awakening_level+ based on the provided hash.
  #
  # @return [void]
  def apply_new_awakening
    self.awakening_id = new_awakening[:id]
    self.awakening_level = new_awakening[:level].present? ? new_awakening[:level].to_i : 1
  end

  ##
  # Checks that a given property value falls within the allowed range based on the specified mastery type.
  #
  # The +property+ parameter is expected to be a hash in the following format:
  #   { ring1: { atk: 300 } }
  #
  # Depending on the +type+, it validates against either over mastery or aetherial mastery values.
  # Adds an error to the record if the value is not within the permitted range.
  #
  # @param property [Hash] the property hash containing the attribute and its value.
  # @param type [String] the type of mastery validation to perform ('over_mastery' or 'aetherial_mastery').
  # @return [void]
  def check_value(property, type)
    # Input format
    # { ring1: { atk: 300 } }

    key = property.keys.first
    modifier = property[key].keys.first

    return if modifier.nil?

    case type
    when 'over_mastery'
      errors.add(key, 'invalid value') unless over_mastery_values.include?(key['strength'])
    when 'aetherial_mastery'
      errors.add(key, 'value too low') if aetherial_mastery_values[modifier][:min] > self[key]['strength']
      errors.add(key, 'value too high') if aetherial_mastery_values[modifier][:max] < self[key]['strength']
    end
  end

  ##
  # Returns a hash mapping over mastery modifier keys to their corresponding attribute names.
  #
  # @return [Hash{Integer => String}] mapping of modifier codes to attribute names.
  def over_mastery_modifiers
    {
      1 => 'atk',
      2 => 'hp',
      3 => 'debuff_success',
      4 => 'skill_cap',
      5 => 'ca_dmg',
      6 => 'ca_cap',
      7 => 'stamina',
      8 => 'enmity',
      9 => 'crit',
      10 => 'da',
      11 => 'ta',
      12 => 'def',
      13 => 'heal',
      14 => 'debuff_resist',
      15 => 'dodge'
    }
  end

  ##
  # Returns a hash containing allowed values for over mastery attributes.
  #
  # @return [Hash{Symbol => Array<Integer>}] mapping of attribute names to their valid values.
  def over_mastery_values
    {
      atk: [300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000],
      hp: [150, 300, 450, 600, 750, 900, 1050, 1200, 1350, 1500],
      debuff_success: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      skill_cap: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      ca_dmg: [10, 12, 14, 16, 18, 20, 22, 24, 27, 30],
      ca_cap: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      crit: [10, 12, 14, 16, 18, 20, 22, 24, 27, 30],
      enmity: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      stamina: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      def: [6, 7, 8, 9, 10, 12, 14, 16, 18, 20],
      heal: [3, 6, 9, 12, 15, 18, 21, 24, 27, 30],
      debuff_resist: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      dodge: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      da: [6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      ta: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    }
  end

  # Returns a hash mapping aetherial mastery modifier keys to their corresponding attribute names.
  #
  # @return [Hash{Integer => String}] mapping of aetherial mastery modifier codes to attribute names.
  def aetherial_mastery_modifiers
    {
      1 => 'da',
      2 => 'ta',
      3 => 'ele_atk',
      4 => 'ele_resist',
      5 => 'stamina',
      6 => 'enmity',
      7 => 'supplemental',
      8 => 'crit',
      9 => 'counter_dodge',
      10 => 'counter_dmg'
    }
  end

  ##
  # Returns a hash containing allowed values for aetherial mastery attributes.
  #
  # @return [Hash{Symbol => Hash{Symbol => Integer}}] mapping of attribute names to their minimum and maximum values.
  def aetherial_mastery_values
    {
      da: {
        min: 10,
        max: 17
      },
      ta: {
        min: 5,
        max: 12
      },
      ele_atk: {
        min: 15,
        max: 22
      },
      ele_resist: {
        min: 5,
        max: 12
      },
      stamina: {
        min: 5,
        max: 12
      },
      enmity: {
        min: 5,
        max: 12
      },
      supplemental: {
        min: 5,
        max: 12
      },
      crit: {
        min: 18,
        max: 35
      },
      counter_dodge: {
        min: 5,
        max: 12
      },
      counter_dmg: {
        min: 10,
        max: 17
      }
    }
  end

  ##
  # Returns an array of valid attack values for over mastery validation.
  #
  # @return [Array<Integer>] list of allowed attack values.
  def atk_values
    [300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000]
  end

  ##
  # Returns an array of valid HP values for over mastery validation.
  #
  # @return [Array<Integer>] list of allowed HP values.
  def hp_values
    [150, 300, 450, 600, 750, 900, 1050, 1200, 1350, 1500]
  end
end
