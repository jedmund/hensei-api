# frozen_string_literal: true

# A base character and its style shift share a granblue_id, so the id is unique per
# style_swap. Character validates that; enforce it in the database too. The unique
# index leads with granblue_id, so it replaces the plain lookup index.
class MakeCharacterGranblueIdUniquePerStyle < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :characters, %i[granblue_id style_swap], unique: true, algorithm: :concurrently,
                                                       name: 'index_characters_on_granblue_id_and_style_swap'
    remove_index :characters, :granblue_id, name: 'index_characters_on_granblue_id', algorithm: :concurrently
  end

  def down
    add_index :characters, :granblue_id, name: 'index_characters_on_granblue_id', algorithm: :concurrently
    remove_index :characters, name: 'index_characters_on_granblue_id_and_style_swap', algorithm: :concurrently
  end
end
