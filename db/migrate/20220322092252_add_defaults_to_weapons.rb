class AddDefaultsToWeapons < ActiveRecord::Migration[6.1]
    def up
        Weapon.find_each do |w|
            if w.flb.nil?
                w.flb = false
                w.save!
            end

            if w.ulb.nil?
                w.ulb = false
                w.save!
            end
        end

        change_column :weapons, :flb, :boolean, default: false, null: false
        change_column :weapons, :ulb, :boolean, default: false, null: false
        change_column :weapons, :ax, :integer, default: 0, null: false
        change_column :weapons, :series, :integer, default: -1, null: false
    end

    def down

    end
end
