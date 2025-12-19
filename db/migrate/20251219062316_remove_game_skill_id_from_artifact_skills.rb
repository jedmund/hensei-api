class RemoveGameSkillIdFromArtifactSkills < ActiveRecord::Migration[8.0]
  def change
    remove_index :artifact_skills, :game_skill_id
    remove_column :artifact_skills, :game_skill_id, :integer
  end
end
