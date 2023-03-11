class CreateBooksTable < ActiveRecord::Migration[7.0]
  def change
    def change
      create_table :books, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
        t.string :name_en, null: false, unique: true
        t.string :name_jp, null: false, unique: true
        t.string :description_en, null: false, unique: true
        t.string :description_jp, null: false, unique: true
        t.string :granblue_id, null: false, unique: true
      end
    end
  end
end
