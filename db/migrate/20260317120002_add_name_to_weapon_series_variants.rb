# frozen_string_literal: true

class AddNameToWeaponSeriesVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_series_variants, :name, :string, null: false, default: ''
  end
end
