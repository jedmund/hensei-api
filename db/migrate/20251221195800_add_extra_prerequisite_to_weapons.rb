# frozen_string_literal: true

class AddExtraPrerequisiteToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :extra_prerequisite, :integer, default: nil
  end
end
