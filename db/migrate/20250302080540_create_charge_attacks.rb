class CreateChargeAttacks < ActiveRecord::Migration[8.0]
  def change
    create_table :charge_attacks, id: :uuid do |t|
      t.string :owner_id, null: false # can be character_granblue_id or weapon_granblue_id
      t.string :owner_type, null: false # "character" or "weapon"
      t.references :skill, type: :uuid, null: false
      t.integer :uncap_level # 0, 3, 4, 5 for uncap level
      t.references :alt_skill, type: :uuid
      t.text :alt_condition # condition for alt version
      t.timestamps null: false
    end

    add_foreign_key :charge_attacks, :skills
    add_foreign_key :charge_attacks, :skills, column: :alt_skill_id
    add_index :charge_attacks, %i[owner_type owner_id uncap_level]
  end
end
