class CreateGridSummons < ActiveRecord::Migration[6.0]
  def change
      create_table :grid_summons, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
          t.references :party, type: :uuid
          t.references :summon, type: :uuid

          t.integer :uncap_level
          t.boolean :main
          t.boolean :friend
          t.integer :position

          t.timestamps
      end
  end
end
