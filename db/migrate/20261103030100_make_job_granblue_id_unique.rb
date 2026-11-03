# frozen_string_literal: true

# Job ids were unique per row because Class I and II jobs shared one. They no
# longer do (see FixClassIiJobIds), so a game id names a single job.
class MakeJobGranblueIdUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :jobs, :granblue_id, unique: true, algorithm: :concurrently
    remove_index :jobs, %i[granblue_id row], name: 'index_jobs_on_granblue_id_and_row', algorithm: :concurrently
  end

  def down
    add_index :jobs, %i[granblue_id row], unique: true, algorithm: :concurrently
    remove_index :jobs, :granblue_id, algorithm: :concurrently
  end
end
