class AddGameSkillIdToArtifactSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :artifact_skills, :game_skill_id, :integer
    add_index :artifact_skills, :game_skill_id, unique: true
  end
end
