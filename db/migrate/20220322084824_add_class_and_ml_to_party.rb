class AddClassAndMlToParty < ActiveRecord::Migration[6.1]
    def change
        add_reference :parties, :class, name: :class_id, type: :uuid, foreign_key: { to_table: :classes }
        add_column :parties, :ml, :integer 
    end
end
