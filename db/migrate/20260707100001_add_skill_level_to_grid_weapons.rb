# frozen_string_literal: true

# Players don't always feed skill fodder to the uncap-implied maximum — three
# golden panels (qBOvon, XJZZmv, HDbPnu) needed a real skill level to match the
# game. NULL keeps the existing uncap/transcendence derivation.
class AddSkillLevelToGridWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :grid_weapons, :skill_level, :integer
    add_column :collection_weapons, :skill_level, :integer
  end
end
