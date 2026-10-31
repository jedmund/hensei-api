# frozen_string_literal: true

# Unique viewers per team per UTC day, flushed from Redis by
# PartyViews::FlushJob. Private: not exposed in any response.
class CreatePartyViewDays < ActiveRecord::Migration[8.1]
  def change
    create_table :party_view_days, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :party, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :date, null: false
      t.integer :views, null: false, default: 0
      t.timestamps
    end
    add_index :party_view_days, %i[party_id date], unique: true
    add_index :party_view_days, :date
  end
end
