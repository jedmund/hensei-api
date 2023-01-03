class AddTranscendenceStepToGridCharacters < ActiveRecord::Migration[6.1]
  def change
    add_column :grid_characters, :transcendence_step, :integer, default: 0, null: false
  end
end
