class MakeGachaDrawableIdUnique < ActiveRecord::Migration[7.0]
  def change
    add_index :gacha, :drawable_id, unique: true
  end
end
