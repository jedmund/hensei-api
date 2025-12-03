# frozen_string_literal: true

class WeaponKeySeries < ApplicationRecord
  belongs_to :weapon_key
  belongs_to :weapon_series

  validates :weapon_key_id, uniqueness: { scope: :weapon_series_id }
end
