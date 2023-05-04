class AddGuidebooks < ActiveRecord::Migration[7.0]
  def change
    create_table :guidebooks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :granblue_id, null: false, unique: true
      t.string :name_en, null: false, unique: true
      t.string :name_jp, null: false, unique: true
      t.string :description_en, null: false
      t.string :description_jp, null: false
      t.timestamps
    end
  end
end
