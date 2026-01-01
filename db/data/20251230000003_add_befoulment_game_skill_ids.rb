# frozen_string_literal: true

class AddBefoulmentGameSkillIds < ActiveRecord::Migration[8.0]
  # Befoulment game_skill_id mapping from game data:
  # 2873: ex_skill_atk_down      | ATK Lowered
  # 2874: ex_skill_ab_atk_down   | Skill DMG Lowered
  # 2875: ex_skill_sp_atk_down   | C.A. DMG Lowered
  # 2876: (doesn't exist)
  # 2877: ex_skill_ta_down       | Multiattack Rate Lowered
  # 2878: ex_skill_ailment_enhance_down | Debuff Success Rate Lowered
  # 2879: ex_skill_hp_down       | HP Cut
  # 2880: ex_skill_def_down      | Def Lowered (already mapped)
  # 2881: ex_skill_turn_damage   | Turn DMG

  BEFOULMENT_GAME_SKILL_IDS = {
    'befoul_atk_down' => 2873,
    'befoul_ability_dmg_down' => 2874,
    'befoul_ca_dmg_down' => 2875,
    'befoul_da_ta_down' => 2877,
    'befoul_debuff_down' => 2878,
    'befoul_hp_down' => 2879,
    'befoul_def_down' => 2880,  # Already set, but include for completeness
    'befoul_dot' => 2881
  }.freeze

  def up
    BEFOULMENT_GAME_SKILL_IDS.each do |slug, game_skill_id|
      WeaponStatModifier.where(slug: slug).update_all(game_skill_id: game_skill_id)
    end
  end

  def down
    # Clear game_skill_ids for befoulments (except def_down which was already set)
    BEFOULMENT_GAME_SKILL_IDS.except('befoul_def_down').each_key do |slug|
      WeaponStatModifier.where(slug: slug).update_all(game_skill_id: nil)
    end
  end
end
