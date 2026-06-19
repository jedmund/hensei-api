# frozen_string_literal: true

class AddUniqueSubstituteIndexesToGridItems < ActiveRecord::Migration[8.0]
  ITEM_FOREIGN_KEYS = {
    grid_weapons: :weapon_id,
    grid_characters: :character_id,
    grid_summons: :summon_id
  }.freeze

  def change
    ITEM_FOREIGN_KEYS.each do |table, fk|
      add_index table,
                [:party_id, :position, fk],
                unique: true,
                where: 'is_substitute',
                name: "index_#{table}_unique_substitute"
    end
  end
end
