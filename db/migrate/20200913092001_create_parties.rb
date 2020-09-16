class CreateParties < ActiveRecord::Migration[6.0]
    def change
        create_table :parties, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
            t.references :user, type: :uuid

            t.string :shortcode

            t.timestamps
        end
    end
end
