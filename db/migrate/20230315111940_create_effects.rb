class CreateEffects < ActiveRecord::Migration[7.0]
  def change
    create_table :effects, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name_en, null: false
      t.string :name_jp, null: false

      t.string :description_en, null: false
      t.string :description_jp, null: false

      t.integer :accuracy_value
      t.string :accuracy_suffix
      t.string :accuracy_comparator

      t.jsonb :strength, array: true
      # {
      #   "min": integer,
      #   "max": integer,
      #   "value": integer,
      #   "suffix": string
      # }

      t.integer :healing_cap

      t.boolean :duration_indefinite, default: false, null: false
      t.integer :duration_value
      t.string :duration_unit

      t.string :notes_en
      t.string :notes_jp
    end
  end
end
