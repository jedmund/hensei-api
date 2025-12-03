# frozen_string_literal: true

class CreateWeaponKeySeries < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_key_series, id: :uuid do |t|
      t.references :weapon_key, type: :uuid, null: false, foreign_key: true
      t.references :weapon_series, type: :uuid, null: false, foreign_key: true
    end

    add_index :weapon_key_series, %i[weapon_key_id weapon_series_id], unique: true
  end
end
