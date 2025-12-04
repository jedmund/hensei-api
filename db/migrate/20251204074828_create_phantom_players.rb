class CreatePhantomPlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :phantom_players, id: :uuid do |t|
      t.references :crew, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :granblue_id
      t.text :notes
      t.references :claimed_by, foreign_key: { to_table: :users }, type: :uuid
      t.references :claimed_from_membership, foreign_key: { to_table: :crew_memberships }, type: :uuid
      t.boolean :claim_confirmed, default: false, null: false

      t.timestamps
    end

    # Unique constraint on granblue_id per crew (only when granblue_id is present)
    add_index :phantom_players, [:crew_id, :granblue_id], unique: true, where: 'granblue_id IS NOT NULL'
  end
end
