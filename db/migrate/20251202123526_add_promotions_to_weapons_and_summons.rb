class AddPromotionsToWeaponsAndSummons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :promotions, :integer, array: true, default: [], null: false
    add_column :summons, :promotions, :integer, array: true, default: [], null: false

    add_index :weapons, :promotions, using: :gin
    add_index :summons, :promotions, using: :gin
  end
end
