# frozen_string_literal: true

class RenamePartyUltimateMasteryToLevel < ActiveRecord::Migration[8.0]
  def change
    rename_column :parties, :ultimate_mastery, :ultimate_mastery_level
  end
end
