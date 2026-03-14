class AddScoreCategoryToArtifactSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :artifact_skills, :score_category, :integer
  end
end
