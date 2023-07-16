# frozen_string_literal: true

class Awakening < ApplicationRecord
  def weapon_awakenings
    WeaponAwakening.where(awakening_id: id)
  end

  def weapons
    weapon_awakenings.map(&:weapon)
  end

  def awakening
    AwakeningBlueprint
  end
end
