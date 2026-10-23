# frozen_string_literal: true

class CreateStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :statuses, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :game_ailment_id
      t.string :name_en, null: false
      t.string :name_jp
      t.string :family
      t.integer :level
      t.string :category, null: false
      t.string :icon
      t.string :wiki_slug
      t.timestamps
    end

    add_index :statuses, :game_ailment_id, unique: true, where: 'game_ailment_id IS NOT NULL',
                                               name: 'index_statuses_on_game_ailment_id'
    add_index :statuses, :family
    add_index :statuses, :name_en
  end
end
