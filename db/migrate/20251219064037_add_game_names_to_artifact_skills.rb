class AddGameNamesToArtifactSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :artifact_skills, :game_name_en, :string
    add_column :artifact_skills, :game_name_jp, :string
    add_index :artifact_skills, :game_name_en
    add_index :artifact_skills, :game_name_jp
  end
end
