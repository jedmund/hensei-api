class AddBaseJobToJobs < ActiveRecord::Migration[6.1]
  def change
    change_table(:jobs) do |t|
      t.references :base_job, type: :uuid, foreign_key: { to_table: 'jobs' }
    end
  end
end
