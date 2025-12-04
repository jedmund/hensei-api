class CreateCrews < ActiveRecord::Migration[8.0]
  def change
    create_table :crews, id: :uuid do |t|
      t.string :name, null: false
      t.string :gamertag
      t.string :granblue_crew_id
      t.text :description

      t.timestamps
    end

    add_index :crews, :name
    add_index :crews, :granblue_crew_id, unique: true, where: "granblue_crew_id IS NOT NULL"
  end
end
