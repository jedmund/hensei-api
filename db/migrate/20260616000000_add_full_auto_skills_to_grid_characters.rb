# frozen_string_literal: true

# Per-ability-slot Full Auto toggles for a character placed in a party.
# Keyed by slot number "1".."4" → boolean (whether that ability is used in
# Full Auto). An absent slot defaults to ON. Party-specific (not collection-synced).
class AddFullAutoSkillsToGridCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :grid_characters, :full_auto_skills, :jsonb, default: {}, null: false
  end
end
