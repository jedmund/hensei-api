# frozen_string_literal: true

class CreateWeaponSeriesVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_series_variants, id: :uuid do |t|
      t.references :weapon_series, null: false, foreign_key: true, type: :uuid
      t.boolean :has_weapon_keys
      t.boolean :has_awakening
      t.integer :num_weapon_keys
      t.integer :augment_type
      t.boolean :element_changeable
      t.boolean :extra
      t.timestamps
    end

    add_reference :weapons, :weapon_series_variant, type: :uuid, foreign_key: true, index: true
  end
end
