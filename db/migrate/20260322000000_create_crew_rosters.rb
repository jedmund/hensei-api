class CreateCrewRosters < ActiveRecord::Migration[8.0]
  def change
    create_table :crew_rosters, id: :uuid do |t|
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :element, null: false
      t.jsonb :items, null: false, default: []
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :crew_rosters, [:crew_id, :element], unique: true
  end
end
