class AddLastUpdatedToParties < ActiveRecord::Migration[8.0]
  def change
    add_column :parties, :last_updated, :datetime
    add_index :parties, :last_updated

    reversible do |dir|
      dir.up { execute "UPDATE parties SET last_updated = created_at" }
    end
  end
end
