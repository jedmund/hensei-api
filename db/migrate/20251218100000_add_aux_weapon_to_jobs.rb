# frozen_string_literal: true

class AddAuxWeaponToJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :jobs, :aux_weapon, :boolean, default: false
  end
end
