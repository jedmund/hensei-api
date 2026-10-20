# frozen_string_literal: true

# Game events (story events, Guild War, collabs…) and the raids they link to.
# `gw_events` is merged into this table in a later, separate change.
class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp
      t.integer :kind, null: false, default: 0
      t.integer :element
      t.integer :event_number
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :image_key
      t.integer :status, null: false, default: 0
      t.jsonb :source_refs, null: false, default: {}
      t.jsonb :source_payload, null: false, default: {}

      t.timestamps
    end

    add_index :events, %i[status starts_at]
    add_index :events, :ends_at
    add_index :events, :kind
    # Unite and Fight numbers are unique among unite_and_fight rows (kind 3).
    add_index :events, :event_number, unique: true, where: 'kind = 3 AND event_number IS NOT NULL',
                                      name: 'index_events_on_unite_and_fight_event_number'

    create_table :event_raids, id: :uuid do |t|
      t.references :event, type: :uuid, null: false, foreign_key: true, index: false
      t.references :raid, type: :uuid, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :event_raids, %i[event_id raid_id], unique: true
  end
end
