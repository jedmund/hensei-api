# frozen_string_literal: true

class WeaponAwakening < ApplicationRecord
  belongs_to :weapon
  belongs_to :awakening

  def weapon
    Weapon.find(weapon_id)
  end

  def awakening
    Awakening.find(awakening_id)
  end
end
