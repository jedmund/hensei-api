# frozen_string_literal: true

# Evoking Solomonis grid fields. seal_state (start / unsealed / sealed) is null
# outside Solomonis parties. unseal_priority ranks a party's sealed weapons and
# summons in one list.
# brought_by_blessing marks the ally chosen with The Hanged Man.
class AddSolomonisFieldsToGridItems < ActiveRecord::Migration[8.1]
  def change
    add_column :grid_weapons, :seal_state, :string
    add_column :grid_weapons, :unseal_priority, :integer
    add_column :grid_summons, :seal_state, :string
    add_column :grid_summons, :unseal_priority, :integer
    add_column :grid_characters, :brought_by_blessing, :boolean, null: false, default: false
  end
end
