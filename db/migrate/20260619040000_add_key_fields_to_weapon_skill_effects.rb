# frozen_string_literal: true

# Some weapon skills are granted by an equipped KEY (Dark Opus pendulum/chain/teluma,
# Draconic teluma, Destroyer anklet) rather than the base weapon. Store those as
# weapon_skill_effects rows tagged with the key's slug, plus a frame_rule describing how
# their frame is determined (weapon_identity / teluma / none). The grid-damage KeySkills
# resolver reads them for a grid_weapon's equipped keys.
class AddKeyFieldsToWeaponSkillEffects < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_skill_effects, :key_slug, :string  # nil = a normal (base-weapon) effect
    add_column :weapon_skill_effects, :frame_rule, :string # weapon_identity | teluma | none
    add_index :weapon_skill_effects, :key_slug
  end
end
