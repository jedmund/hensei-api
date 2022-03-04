class AddDefaultValuesToUser < ActiveRecord::Migration[6.1]
    def change
        change_column :users, :picture, :string, :default => "gran"
        change_column :users, :language, :string, :default => "en"
        change_column :users, :private, :boolean, :default => false
    end
end
