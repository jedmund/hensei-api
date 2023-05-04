class MakeUserIdUniqueInSparks < ActiveRecord::Migration[7.0]
  def change
    add_index :sparks, :user_id, unique: true
  end
end
