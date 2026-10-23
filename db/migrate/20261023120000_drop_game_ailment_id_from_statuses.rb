# frozen_string_literal: true

# Statuses are keyed by the game's display status ids (game_status_id). The internal ailment
# ids were paired with the wiki's names by position, which was wrong, and nothing reads them
# any more. Rolling back re-adds the column and its index, empty.
class DropGameAilmentIdFromStatuses < ActiveRecord::Migration[8.1]
  def change
    remove_index :statuses, :game_ailment_id, unique: true, where: 'game_ailment_id IS NOT NULL',
                                              name: 'index_statuses_on_game_ailment_id'
    remove_column :statuses, :game_ailment_id, :string
  end
end
