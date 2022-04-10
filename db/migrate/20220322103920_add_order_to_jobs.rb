class AddOrderToJobs < ActiveRecord::Migration[6.1]
    def change
        add_column :jobs, :order, :integer
    end
end
