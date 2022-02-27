class AddElementToParties < ActiveRecord::Migration[6.1]
    def change
        add_column :parties, :element, :integer
    end
end
