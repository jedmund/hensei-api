class ChangeDefaultValueOnChargeAttack < ActiveRecord::Migration[7.0]
  def change
    change_column :parties, :charge_attack, :boolean, null: false, default: true
  end
end
