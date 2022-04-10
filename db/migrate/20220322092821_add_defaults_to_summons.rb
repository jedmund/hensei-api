class AddDefaultsToSummons < ActiveRecord::Migration[6.1]
    def change
        def up
            Summon.find_each do |s|
                if s.flb.nil?
                    s.flb = false
                    s.save!
                end
    
                if s.ulb.nil?
                    s.ulb = false
                    s.save!
                end
            end
    
            change_column :summons, :flb, :boolean, default: false, null: false
            change_column :summons, :ulb, :boolean, default: false, null: false
        end
    
        def down
    
        end
    end
end
