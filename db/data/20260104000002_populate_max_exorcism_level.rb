# frozen_string_literal: true

class PopulateMaxExorcismLevel < ActiveRecord::Migration[8.0]
  def up
    # Set max_exorcism_level = 5 for all weapons that belong to a series with befoulment augment type
    updated = Weapon
      .joins(:weapon_series)
      .where(weapon_series: { augment_type: :befoulment })
      .update_all(max_exorcism_level: 5)

    puts "  Updated #{updated} weapons with max_exorcism_level = 5"
  end

  def down
    Weapon
      .joins(:weapon_series)
      .where(weapon_series: { augment_type: :befoulment })
      .update_all(max_exorcism_level: nil)
  end
end
