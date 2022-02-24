class AddGroupToRaids < ActiveRecord::Migration[6.1]
    def change
        add_column :raids, :group, :integer
    end
end
