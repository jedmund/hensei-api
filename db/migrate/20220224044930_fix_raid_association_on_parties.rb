class FixRaidAssociationOnParties < ActiveRecord::Migration[6.1]
    def change
        add_column :parties, :raid_id, :uuid
        remove_column :parties, :raids_id, :bigint
    end
end
