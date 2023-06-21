# frozen_string_literal: true

class GridCharacter < ApplicationRecord
  belongs_to :awakening, optional: true
  belongs_to :party,
             counter_cache: :characters_count,
             inverse_of: :characters
  validates_presence_of :party

  validate :validate_awakening_level, on: :update
  validate :transcendence, on: :update
  validate :validate_over_mastery_values, on: :update
  validate :validate_aetherial_mastery_value, on: :update
  validate :over_mastery_attack_matches_hp, on: :update

  ##### Amoeba configuration
  amoeba do
    set ring1: { modifier: nil, strength: nil }
    set ring2: { modifier: nil, strength: nil }
    set ring3: { modifier: nil, strength: nil }
    set ring4: { modifier: nil, strength: nil }
    set earring: { modifier: nil, strength: nil }
    set perpetuity: false
  end

  # Add awakening before the model saves
  before_save :add_awakening

  def validate_awakening_level
    errors.add(:awakening, 'awakening level too low') if awakening_level < 1
    errors.add(:awakening, 'awakening level too high') if awakening_level > 9
  end

  def transcendence
    errors.add(:transcendence_step, 'character has no transcendence') if transcendence_step.positive? && !character.ulb
    errors.add(:transcendence_step, 'transcendence step too high') if transcendence_step > 5 && character.ulb
    errors.add(:transcendence_step, 'transcendence step too low') if transcendence_step.negative? && character.ulb
  end

  def over_mastery_attack
    errors.add(:ring1, 'invalid value') unless ring1['modifier'].nil? || atk_values.include?(ring1['strength'])
  end

  def over_mastery_hp
    return if ring2['modifier'].nil?

    errors.add(:ring2, 'invalid value') unless hp_values.include?(ring2['strength'])
  end

  def over_mastery_attack_matches_hp
    return if ring1[:modifier].nil? && ring2[:modifier].nil?

    return if ring2[:strength] == (ring1[:strength] / 2)

    errors.add(:over_mastery,
               'over mastery attack and hp values do not match')
  end

  def validate_over_mastery_values
    [ring1, ring2, ring3, ring4].each_with_index do |ring, index|
      next if ring['modifier'].nil?

      modifier = over_mastery_modifiers[ring['modifier']]
      check_value({ "ring#{index}": { ring[modifier] => ring['strength'] } },
                  'over_mastery')
    end
  end

  def validate_aetherial_mastery_value
    return if earring['modifier'].nil?

    return unless earring['modifier'].positive?

    modifier = aetherial_mastery_modifiers[earring['modifier']].to_sym
    check_value({ "earring": { modifier => earring['strength'] } },
                'aetherial_mastery')
  end

  def character
    Character.find(character_id)
  end

  def blueprint
    GridCharacterBlueprint
  end

  private

  def add_awakening
    if self.awakening.nil?
      self.awakening = Awakening.where(slug: "character-balanced").sole
    end
  end

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

  def atk_values
    [300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000]
  end

  def hp_values
    [150, 300, 450, 600, 750, 900, 1050, 1200, 1350, 1500]
  end
end
