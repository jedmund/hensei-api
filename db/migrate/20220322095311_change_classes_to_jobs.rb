class ChangeClassesToJobs < ActiveRecord::Migration[6.1]
    def change
        rename_table :classes, :jobs
    end
end
