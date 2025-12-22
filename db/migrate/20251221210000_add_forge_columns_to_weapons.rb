# frozen_string_literal: true

class AddForgeColumnsToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :forged_from, :string
    add_column :weapons, :forge_chain_id, :uuid
    add_column :weapons, :forge_order, :integer

    add_index :weapons, :forged_from
    add_index :weapons, :forge_chain_id
  end
end
