# frozen_string_literal: true

class AddCollectionReferencesToGridItems < ActiveRecord::Migration[8.0]
  def change
    add_reference :grid_characters, :collection_character,
                  type: :uuid, foreign_key: true, null: true
    add_reference :grid_weapons, :collection_weapon,
                  type: :uuid, foreign_key: true, null: true
    add_reference :grid_summons, :collection_summon,
                  type: :uuid, foreign_key: true, null: true
    add_reference :grid_artifacts, :collection_artifact,
                  type: :uuid, foreign_key: true, null: true
  end
end
