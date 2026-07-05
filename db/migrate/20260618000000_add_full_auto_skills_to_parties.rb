# frozen_string_literal: true

# Per-slot Full Auto toggles for a party's MC (main character) abilities.
# Keyed by slot number "0".."3" → boolean (whether that ability is used in
# Full Auto). An absent slot defaults to ON. Mirrors GridCharacter#full_auto_skills.
class AddFullAutoSkillsToParties < ActiveRecord::Migration[8.0]
  def change
    add_column :parties, :full_auto_skills, :jsonb, default: {}, null: false
  end
end
