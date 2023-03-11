class AddFullAutoTogglesToGridCharacter < ActiveRecord::Migration[7.0]
  def change
    change_table(:grid_characters) do |t|
      t.boolean :skill0_enabled, null: false, default: true
      t.boolean :skill1_enabled, null: false, default: true
      t.boolean :skill2_enabled, null: false, default: true
      t.boolean :skill3_enabled, null: false, default: true
    end
  end
end
