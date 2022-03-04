class AddNotNullableToUser < ActiveRecord::Migration[6.1]
    def change
        change_column :users, :language, :string, :default => "en", :null => false
        change_column :users, :private, :boolean, :default => false, :null => false
    end
end
