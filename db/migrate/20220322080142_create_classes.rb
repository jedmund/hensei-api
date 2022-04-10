class CreateClasses < ActiveRecord::Migration[6.0]
  def change
      create_table :classes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
          t.string :name_en
          t.string :name_jp

          t.integer :proficiency1
          t.integer :proficiency2

          t.string :row
          t.boolean :ml, default: false
      end
  end
end