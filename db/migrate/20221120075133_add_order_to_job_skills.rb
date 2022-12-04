class AddOrderToJobSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :job_skills, :order, :integer
  end
end
