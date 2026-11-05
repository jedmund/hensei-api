# frozen_string_literal: true

class WeaponKey < ApplicationRecord
  has_many :weapon_key_series, dependent: :destroy
  has_many :weapon_series, through: :weapon_key_series

  def compatible_with_weapon?(weapon)
    return false if weapon.weapon_series.blank?

    weapon_series.include?(weapon.weapon_series)
  end
end
