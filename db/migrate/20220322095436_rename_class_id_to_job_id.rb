class RenameClassIdToJobId < ActiveRecord::Migration[6.1]
    def change
        rename_column :parties, :class_id, :job_id
    end
end
