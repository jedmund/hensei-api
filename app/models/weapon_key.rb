# frozen_string_literal: true

class WeaponKey < ApplicationRecord
  has_many :weapon_key_series, dependent: :destroy
  has_many :weapon_series, through: :weapon_key_series

  def blueprint
    WeaponKeyBlueprint
  end

  def compatible_with_weapon?(weapon)
    return false unless weapon.weapon_series.present?

    weapon_series.include?(weapon.weapon_series)
  end
end
