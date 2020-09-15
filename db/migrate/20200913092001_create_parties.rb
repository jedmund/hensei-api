class CreateParties < ActiveRecord::Migration[6.0]
    def change
        create_table :parties, id: :uuid do |t|
            t.belongs_to :user, type: :uuid

            t.string :hash

            t.string :characters, array: true, default: []
            t.string :weapons, array: true, default: []
            t.string :summons, array: true, default: []

            t.timestamps
        end
    end
end
