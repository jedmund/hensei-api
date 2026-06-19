# frozen_string_literal: true

# Stores the game asset stem for a skill version's icon, e.g. "625_4"
# (ability_id + border-color number). The asset lives at
# .../ui/icon/ability/m/{game_icon}.png. Distinct from `icon`, which holds the
# gbf.wiki filename. Sourced from game_raw_en ability `class_name`, falling back
# to a wiki icon already in `Ability_m_{id}_{N}.png` form.
class AddGameIconToCharacterSkillVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :character_skill_versions, :game_icon, :string
  end
end
