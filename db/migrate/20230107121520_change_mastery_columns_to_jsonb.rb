class ChangeMasteryColumnsToJsonb < ActiveRecord::Migration[7.0]
  def change
    # Remove old columns
    remove_column :grid_characters, :ring_modifier1, :integer
    remove_column :grid_characters, :ring_modifier2, :integer
    remove_column :grid_characters, :ring_modifier3, :integer
    remove_column :grid_characters, :ring_modifier4, :integer
    remove_column :grid_characters, :ring_strength1, :integer
    remove_column :grid_characters, :ring_strength2, :integer
    remove_column :grid_characters, :ring_strength3, :integer
    remove_column :grid_characters, :ring_strength4, :integer
    remove_column :grid_characters, :earring_modifier, :integer
    remove_column :grid_characters, :earring_strength, :integer

    # Add new columns
    add_column :grid_characters, :ring1, :jsonb, default: { modifier: nil, strength: nil }
    add_column :grid_characters, :ring2, :jsonb, default: { modifier: nil, strength: nil }
    add_column :grid_characters, :ring3, :jsonb, default: { modifier: nil, strength: nil }
    add_column :grid_characters, :ring4, :jsonb, default: { modifier: nil, strength: nil }
    add_column :grid_characters, :earring, :jsonb, default: { modifier: nil, strength: nil }
  end
end
