# frozen_string_literal: true

class WeaponAwakening < ApplicationRecord
  belongs_to :weapon
  belongs_to :awakening
end
