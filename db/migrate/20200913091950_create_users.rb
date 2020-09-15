class CreateUsers < ActiveRecord::Migration[6.0]
    def change
        create_table :users, id: :uuid do |t|
            t.string :email
            t.string :password
            t.string :username
            t.integer :granblue_id

            t.timestamps
        end
    end
end
