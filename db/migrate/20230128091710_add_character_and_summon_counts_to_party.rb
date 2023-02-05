class AddCharacterAndSummonCountsToParty < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :characters_count, :integer
    add_column :parties, :summons_count, :integer
  end
end
