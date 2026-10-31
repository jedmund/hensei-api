# frozen_string_literal: true

# Editors mark the endgame raids crew members can record element coverage for.
class AddTrackableToRaids < ActiveRecord::Migration[8.1]
  def change
    add_column :raids, :trackable, :boolean, default: false, null: false
  end
end
