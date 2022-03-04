class AddFieldsToUser < ActiveRecord::Migration[6.1]
    def change
        add_column :users, :picture, :string
        add_column :users, :language, :string
        add_column :users, :private, :boolean
    end
end
