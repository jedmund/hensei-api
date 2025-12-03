# frozen_string_literal: true

class AddRerollSlotToArtifacts < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_artifacts, :reroll_slot, :integer
    add_column :grid_artifacts, :reroll_slot, :integer
  end
end
