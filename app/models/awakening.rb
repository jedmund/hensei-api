# frozen_string_literal: true

class Awakening < ApplicationRecord
  has_many :weapon_awakenings, foreign_key: :awakening_id
  has_many :weapons, through: :weapon_awakenings

  def awakening
    AwakeningBlueprint
  end
end
