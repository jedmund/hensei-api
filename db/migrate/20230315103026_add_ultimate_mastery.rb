class AddUltimateMastery < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :ultimate_mastery, :integer, null: true
    add_column :jobs, :ultimate_mastery, :boolean, default: false, null: false
  end
end
