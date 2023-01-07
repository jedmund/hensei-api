# frozen_string_literal: true

class GridCharacter < ApplicationRecord
  belongs_to :party

  validate :awakening_level, on: :update
  validate :transcendence, on: :update
  validate :over_mastery_attack, on: :update
  validate :over_mastery_hp, on: :update
  validate :over_mastery_attack_matches_hp, on: :update

  def awakening_level
    unless awakening.nil?
      errors.add(:awakening, 'awakening level too low') if awakening["level"] < 1
      errors.add(:awakening, 'awakening level too high') if awakening["level"] > 9
    end
  end

  def transcendence
    errors.add(:transcendence_step, 'character has no transcendence') if transcendence_step > 0 && !character.ulb
    errors.add(:transcendence_step, 'transcendence step too high') if transcendence_step > 5 && character.ulb
    errors.add(:transcendence_step, 'transcendence step too low') if transcendence_step < 0 && character.ulb

  end

  def over_mastery_attack
    errors.add(:ring1, 'invalid value') unless ring1["modifier"].nil? || atk_values.include?(ring1["strength"])
  end

  def over_mastery_hp
    unless ring2["modifier"].nil?
      errors.add(:ring2, 'invalid value') unless hp_values.include?(ring2["strength"])
    end
  end

  def over_mastery_attack_matches_hp
    unless ring1[:modifier].nil? && ring2[:modifier].nil?
      errors.add(:over_mastery, 'over mastery attack and hp values do not match') unless ring2[:strength] == (ring1[:strength] / 2)
    end
  end

  def character
    Character.find(character_id)
  end

  def blueprint
    GridCharacterBlueprint
  end

  private

  def atk_values
    [300, 600, 900, 1200, 1500, 1800, 2100, 2400, 2700, 3000]
  end

  def hp_values
    [150, 300, 450, 600, 750, 900, 1050, 1200, 1350, 1500]
  end
end
