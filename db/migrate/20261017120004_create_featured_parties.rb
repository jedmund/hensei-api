# frozen_string_literal: true

# Staff picks, optionally tied to an event.
class CreateFeaturedParties < ActiveRecord::Migration[8.1]
  def change
    create_table :featured_parties, id: :uuid do |t|
      t.references :event, type: :uuid, foreign_key: true
      t.references :party, type: :uuid, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :note_en
      t.string :note_jp

      t.timestamps
    end

    add_index :featured_parties, %i[event_id party_id], unique: true
  end
end
