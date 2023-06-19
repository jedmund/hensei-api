class CreateWeaponAwakeningsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :weapon_awakenings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :weapon, null: false, foreign_key: true, type: :uuid
      t.references :awakening, null: false, foreign_key: true, type: :uuid
    end
  end
end
