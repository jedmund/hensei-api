class AddAwakeningsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :awakenings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name_en, null: false
      t.string :name_jp, null: false
      t.string :slug, null: false
      t.string :type, null: false
    end
  end
end
