# frozen_string_literal: true

class AddWeaponSeriesIdToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_reference :weapons, :weapon_series, type: :uuid, foreign_key: true, index: true
  end
end
