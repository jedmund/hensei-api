# frozen_string_literal: true

# Which elements a user has teams for in each trackable raid. Elements use the
# game's numbering (GranblueEnums::ELEMENTS).
class CreateUserRaidElements < ActiveRecord::Migration[8.1]
  def change
    create_table :user_raid_elements, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.references :raid, type: :uuid, null: false, foreign_key: true
      t.integer :element, null: false
      t.timestamps
    end

    add_index :user_raid_elements, %i[user_id raid_id element], unique: true,
                                                               name: 'index_user_raid_elements_unique'
  end
end
