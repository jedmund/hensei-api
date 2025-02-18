class MakeJobForeignKeyDeferrable < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :jobs, column: :base_job_id
    add_foreign_key :jobs, :jobs, column: :base_job_id, deferrable: :deferred, initially_deferred: true
  end
end
