class AddElementToRaids < ActiveRecord::Migration[6.1]
    def change
        add_column :raids, :element, :integer
    end
end
