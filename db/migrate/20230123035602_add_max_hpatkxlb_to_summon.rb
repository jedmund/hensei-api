class AddMaxHpatkxlbToSummon < ActiveRecord::Migration[7.0]
  def change
    add_column :summons, :max_atk_xlb, :integer
    add_column :summons, :max_hp_xlb, :integer
  end
end
