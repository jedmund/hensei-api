class CreateCrewMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :crew_memberships, id: :uuid do |t|
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.integer :role, default: 0, null: false
      t.boolean :retired, default: false, null: false
      t.datetime :retired_at

      t.timestamps
    end

    add_index :crew_memberships, [:crew_id, :user_id], unique: true
    add_index :crew_memberships, [:crew_id, :role]
    add_index :crew_memberships, [:user_id],
              unique: true,
              where: "retired = false",
              name: "index_crew_memberships_on_active_user"
  end
end
