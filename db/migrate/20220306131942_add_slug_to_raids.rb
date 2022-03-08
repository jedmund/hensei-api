class AddSlugToRaids < ActiveRecord::Migration[6.1]
    def change
        add_column :raids, :slug, :string
    end
end
