# frozen_string_literal: true

class AddDrawableIdentityToGachaRateups < ActiveRecord::Migration[8.0]
  def up
    add_column :gacha_rateups, :drawable_type, :string
    add_column :gacha_rateups, :drawable_id, :uuid
    add_check_constraint :gacha_rateups, <<~SQL.squish, name: 'gacha_rateups_drawable_pair'
      (drawable_type IS NULL AND drawable_id IS NULL) OR
      (drawable_type IS NOT NULL AND drawable_id IS NOT NULL AND drawable_type IN ('Weapon', 'Summon'))
    SQL
    add_index :gacha_rateups, %i[user_id drawable_type drawable_id], name: 'index_gacha_rateups_on_user_and_drawable'
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Keep drawable identity: new-only rate-ups cannot be reconstructed from gacha_id'
  end
end
