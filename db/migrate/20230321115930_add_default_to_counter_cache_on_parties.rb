class AddDefaultToCounterCacheOnParties < ActiveRecord::Migration[7.0]
  def change
    change_column_default :parties, :characters_count, 0
    change_column_default :parties, :weapons_count, 0
    change_column_default :parties, :summons_count, 0
  end
end
