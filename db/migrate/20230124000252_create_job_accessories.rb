class CreateJobAccessories < ActiveRecord::Migration[7.0]
  def change
    create_table :job_accessories, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :job, type: :uuid

      t.string :name_en, null: false, unique: true
      t.string :name_jp, null: false, unique: true
      t.string :granblue_id, null: false, unique: true

      t.integer :rarity
      t.date :release_date
    end
  end
end
