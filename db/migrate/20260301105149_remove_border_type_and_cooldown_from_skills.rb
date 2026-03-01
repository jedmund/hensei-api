# frozen_string_literal: true

class RemoveBorderTypeAndCooldownFromSkills < ActiveRecord::Migration[7.1]
  def change
    remove_column :skills, :border_type, :integer
    remove_column :skills, :cooldown, :integer
  end
end
