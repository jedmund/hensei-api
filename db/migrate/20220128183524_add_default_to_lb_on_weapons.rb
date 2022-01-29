class AddDefaultToLbOnWeapons < ActiveRecord::Migration[6.1]
    def change
        def self.up
            change_column :weapons, :flb, :boolean, default: false
            change_column :weapons, :ulb, :boolean, default: false
        end
  
        def self.down
            change_column :weapons, :flb, :boolean, default: nil
            change_column :weapons, :ulb, :boolean, default: nil
        end
    end
end
