class ChangeGachaDrawableIdToUuid < ActiveRecord::Migration[7.0]
  def change
    remove_column :gacha, :drawable_id, :bigint
    remove_column :gacha, :drawable_type, :string
    add_reference :gacha, :drawable, polymorphic: true, type: :uuid
  end
end
