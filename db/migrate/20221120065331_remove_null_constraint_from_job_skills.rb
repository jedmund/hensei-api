class RemoveNullConstraintFromJobSkills < ActiveRecord::Migration[6.1]
  def change
    change_column :job_skills, :name_en, :string, unique: false
    change_column :job_skills, :name_jp, :string, unique: false
  end
end
