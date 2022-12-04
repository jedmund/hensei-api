class AddBaseAndGroupToJobSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :job_skills, :base, :boolean, default: false
    add_column :job_skills, :group, :integer
  end
end
