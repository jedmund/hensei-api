class CreateUsers < ActiveRecord::Migration[6.0]
    def change
        create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
            t.string :email, :unique => true
            t.string :password_digest
            t.string :username, :unique => true
            t.integer :granblue_id, :unique => true

            t.timestamps
        end
    end
end
