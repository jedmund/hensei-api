class RemoveGroupFromJobSkills < ActiveRecord::Migration[6.1]
  def change
    remove_column :job_skills, :group, :integer
  end
end
