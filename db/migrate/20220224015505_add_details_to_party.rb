class AddDetailsToParty < ActiveRecord::Migration[6.1]
    def change
        create_table :raids, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
            t.string :name_en
            t.string :name_jp
            t.integer :level
        end

        add_column :parties, :name, :string
        add_column :parties, :description, :text
        add_reference :parties, :raids, index: true
    end
end
