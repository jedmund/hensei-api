class SplitGuidebooksOnParty < ActiveRecord::Migration[7.0]
  def change
    remove_column :parties, :guidebook_ids
    add_reference :parties, :guidebook0, type: :uuid, foreign_key: { to_table: :guidebooks }
    add_reference :parties, :guidebook1, type: :uuid, foreign_key: { to_table: :guidebooks }
    add_reference :parties, :guidebook2, type: :uuid, foreign_key: { to_table: :guidebooks }
  end
end
