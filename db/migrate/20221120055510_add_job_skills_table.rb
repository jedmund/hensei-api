class AddJobSkillsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :job_skills, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
        t.references :job, type: :uuid
        t.string :name_en, null: false, unique: true
        t.string :name_jp, null: false, unique: true
        t.string :slug, null: false, unique: true
        t.integer :color, null: false
        t.boolean :main, default: false
        t.boolean :sub, default: false
        t.boolean :emp, default: false
    end
  end
end
