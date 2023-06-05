class AddRecruitsToWeapon < ActiveRecord::Migration[7.0]
  def change
    add_reference :weapons, :recruits, null: true, to_table: 'character_id', type: :uuid
  end
end
