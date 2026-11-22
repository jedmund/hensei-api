# frozen_string_literal: true

# Some Wonders only boost certain characters (every version of them): the
# Eternals, the Divine Generals, or the story crew for Letters from Dad.
# Teams hide those Wonders unless such a character is in the grid.
class AddCharacterRequirementsToWonders < ActiveRecord::Migration[8.1]
  def change
    add_column :wonders, :required_character_series, :string
    # Game character ids (characters.character_id), shared by every version
    add_column :wonders, :required_character_game_ids, :integer, array: true, default: [], null: false
  end
end
