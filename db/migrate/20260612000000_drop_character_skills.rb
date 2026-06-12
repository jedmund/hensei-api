# frozen_string_literal: true

class DropCharacterSkills < ActiveRecord::Migration[8.0]
  def up
    drop_table :character_skills, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
