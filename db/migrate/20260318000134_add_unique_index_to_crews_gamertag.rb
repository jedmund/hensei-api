class AddUniqueIndexToCrewsGamertag < ActiveRecord::Migration[8.0]
  def change
    add_index :crews, :gamertag, unique: true, where: "gamertag IS NOT NULL"
  end
end
