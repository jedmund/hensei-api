class AddFieldsToJobSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :job_skills, :image_id, :string
    add_column :job_skills, :action_id, :integer

    add_index :job_skills, :image_id
    add_index :job_skills, :action_id
  end
end
