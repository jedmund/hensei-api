class AddGranblueIdToJobs < ActiveRecord::Migration[7.0]
  def change
    add_column :jobs, :granblue_id, :string
  end
end
