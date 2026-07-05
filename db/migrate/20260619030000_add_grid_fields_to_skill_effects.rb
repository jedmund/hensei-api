# frozen_string_literal: true

# Passive character support skills can boost the grid (e.g. "Hudor Arche: 20% boost to
# Water's/Tsunami's/Hoarfrost's/Oceansoul's weapon skills") — they contribute to the
# per-frame summon-aura total. Model them as SkillEffect rows (effect_type
# "weapon_skill_boost") with the frame + element they amplify.
class AddGridFieldsToSkillEffects < ActiveRecord::Migration[8.0]
  def change
    add_column :skill_effects, :frame, :string   # normal | omega | (null)
    add_column :skill_effects, :element, :string  # fire|water|earth|wind|light|dark|all | (null)
  end
end
