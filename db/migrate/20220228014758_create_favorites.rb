class CreateFavorites < ActiveRecord::Migration[6.1]
    def change
        create_table :favorites, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
            t.references :user, type: :uuid
            t.references :party, type: :uuid
            t.timestamps
        end
    end
end
