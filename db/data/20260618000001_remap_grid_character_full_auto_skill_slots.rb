# frozen_string_literal: true

# Unify GridCharacter#full_auto_skills slot keys to the 0-indexed convention
# shared with the MC abilities (Party#full_auto_skills). Existing rows were keyed
# "1".."4"; shift them down to "0".."3", preserving order and values.
class RemapGridCharacterFullAutoSkillSlots < ActiveRecord::Migration[8.0]
  SHIFT = { '1' => '0', '2' => '1', '3' => '2', '4' => '3' }.freeze

  def up
    remap_with(SHIFT)
  end

  def down
    remap_with(SHIFT.invert)
  end

  private

  def remap_with(mapping)
    count = 0
    GridCharacter.where.not(full_auto_skills: {}).find_each do |gc|
      remapped = gc.full_auto_skills.transform_keys { |k| mapping.fetch(k.to_s, k.to_s) }
      gc.update_column(:full_auto_skills, remapped)
      count += 1
    end
    puts "Remapped full_auto_skills slots on #{count} grid_characters"
  end
end
