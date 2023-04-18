class AddGuidebooksToParty < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :guidebooks, :uuid, array: true, default: [], null: false
  end
end
