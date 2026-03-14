class AddSubstitutionFieldsToGridItems < ActiveRecord::Migration[8.0]
  def change
    %i[grid_characters grid_weapons grid_summons].each do |table|
      add_column table, :is_substitute, :boolean, default: false, null: false
      add_reference table, :role, type: :uuid, foreign_key: { to_table: :roles }, null: true
      add_column table, :substitution_note, :text

      add_index table, :is_substitute
    end
  end
end
