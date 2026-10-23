# frozen_string_literal: true

class CollapseRolesToCharactersAndRenameDescription < ActiveRecord::Migration[8.0]
  def change
    # Roles narrowed to characters only — drop slot_type and rename catalog table.
    remove_column :roles, :slot_type, :string
    rename_table  :roles, :grid_character_roles

    # Roles no longer apply to weapons or summons.
    remove_reference :grid_weapons, :role, type: :uuid, index: true
    remove_reference :grid_summons, :role, type: :uuid, index: true

    # Replace the single role_id on grid_characters with a join table.
    remove_reference :grid_characters, :role, type: :uuid, index: true

    create_table :grid_character_role_assignments, id: :uuid do |t|
      t.references :grid_character,      type: :uuid, null: false, foreign_key: true
      t.references :grid_character_role, type: :uuid, null: false, foreign_key: true
      t.timestamps
      t.index %i[grid_character_id grid_character_role_id],
              unique: true, name: 'idx_gc_role_assignments_unique'
    end

    # The substitution_note column was misnamed — it's a per-item description.
    rename_column :grid_characters, :substitution_note, :description
    rename_column :grid_weapons,    :substitution_note, :description
    rename_column :grid_summons,    :substitution_note, :description
  end
end
