class AddRingsEarringsToGridCharacters < ActiveRecord::Migration[6.1]
  def change
    add_column :grid_characters, :ring_modifier1, :integer
    add_column :grid_characters, :ring_strength1, :float

    add_column :grid_characters, :ring_modifier2, :integer
    add_column :grid_characters, :ring_strength2, :float

    add_column :grid_characters, :ring_modifier3, :integer
    add_column :grid_characters, :ring_strength3, :float

    add_column :grid_characters, :ring_modifier4, :integer
    add_column :grid_characters, :ring_strength4, :float

    add_column :grid_characters, :earring_modifier, :integer
    add_column :grid_characters, :earring_strength, :float
  end
end
