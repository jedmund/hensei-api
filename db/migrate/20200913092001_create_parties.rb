class CreateParties < ActiveRecord::Migration[6.0]
    def change
            t.belongs_to :user, type: :uuid
        create_table :parties, id: :uuid, default: -> { "gen_random_uuid()" } do |t|

            t.string :hash

            t.string :characters, array: true, default: []
            t.string :weapons, array: true, default: []
            t.string :summons, array: true, default: []

            t.timestamps
        end
    end
end
