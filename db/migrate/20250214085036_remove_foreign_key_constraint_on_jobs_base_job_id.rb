class RemoveForeignKeyConstraintOnJobsBaseJobId < ActiveRecord::Migration[8.0]
  # Removes the self-referential foreign key constraint on jobs.base_job_id.
  # This constraint was causing issues when seeding job records via CSV.
  def change
    # Check if the foreign key exists before removing it
    if foreign_key_exists?(:jobs, column: :base_job_id)
      remove_foreign_key :jobs, column: :base_job_id
      Rails.logger.info 'Removed foreign key constraint on jobs.base_job_id'
    else
      Rails.logger.info 'No foreign key on jobs.base_job_id found'
    end
  end
end
