# frozen_string_literal: true

class MigrateAxModifiersToFk < ActiveRecord::Migration[8.0]
  # Old AX_MAPPING from WeaponProcessor: game_skill_id (string) => internal_value (integer)
  # We need the reverse: internal_value => game_skill_id
  OLD_INTERNAL_TO_GAME_SKILL_ID = {
    2 => 1588,   # HP
    0 => 1589,   # ATK
    1 => 1590,   # DEF
    3 => 1591,   # C.A. DMG
    4 => 1592,   # Multiattack Rate
    9 => 1593,   # Debuff Resistance
    13 => 1594,  # Elemental ATK
    10 => 1595,  # Healing
    5 => 1596,   # Double Attack Rate
    6 => 1597,   # Triple Attack Rate
    8 => 1599,   # C.A. DMG Cap
    12 => 1600,  # Stamina
    11 => 1601,  # Enmity
    15 => 1719,  # Supplemental Skill DMG
    16 => 1720,  # Supplemental C.A. DMG
    17 => 1721,  # Elemental DMG Reduction
    14 => 1722   # Normal ATK DMG Cap
  }.freeze

  def up
    # Build lookup cache: game_skill_id -> weapon_stat_modifier.id
    modifier_by_game_skill_id = WeaponStatModifier.pluck(:game_skill_id, :id).to_h

    # Migrate CollectionWeapon ax_modifier1
    CollectionWeapon.where.not(ax_modifier1: nil).find_each do |cw|
      game_skill_id = OLD_INTERNAL_TO_GAME_SKILL_ID[cw.ax_modifier1]
      modifier_id = game_skill_id ? modifier_by_game_skill_id[game_skill_id] : nil
      if modifier_id
        cw.update_columns(ax_modifier1_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier1=#{cw.ax_modifier1} on CollectionWeapon##{cw.id}"
      end
    end

    # Migrate CollectionWeapon ax_modifier2
    CollectionWeapon.where.not(ax_modifier2: nil).find_each do |cw|
      game_skill_id = OLD_INTERNAL_TO_GAME_SKILL_ID[cw.ax_modifier2]
      modifier_id = game_skill_id ? modifier_by_game_skill_id[game_skill_id] : nil
      if modifier_id
        cw.update_columns(ax_modifier2_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier2=#{cw.ax_modifier2} on CollectionWeapon##{cw.id}"
      end
    end

    # Migrate GridWeapon ax_modifier1
    GridWeapon.where.not(ax_modifier1: nil).find_each do |gw|
      game_skill_id = OLD_INTERNAL_TO_GAME_SKILL_ID[gw.ax_modifier1]
      modifier_id = game_skill_id ? modifier_by_game_skill_id[game_skill_id] : nil
      if modifier_id
        gw.update_columns(ax_modifier1_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier1=#{gw.ax_modifier1} on GridWeapon##{gw.id}"
      end
    end

    # Migrate GridWeapon ax_modifier2
    GridWeapon.where.not(ax_modifier2: nil).find_each do |gw|
      game_skill_id = OLD_INTERNAL_TO_GAME_SKILL_ID[gw.ax_modifier2]
      modifier_id = game_skill_id ? modifier_by_game_skill_id[game_skill_id] : nil
      if modifier_id
        gw.update_columns(ax_modifier2_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier2=#{gw.ax_modifier2} on GridWeapon##{gw.id}"
      end
    end
  end

  def down
    # Build reverse lookup: game_skill_id -> old internal value
    game_skill_id_to_internal = OLD_INTERNAL_TO_GAME_SKILL_ID.invert

    # Reverse: copy FK back to integer columns using old internal values
    WeaponStatModifier.find_each do |modifier|
      next unless modifier.game_skill_id

      internal_value = game_skill_id_to_internal[modifier.game_skill_id]
      next unless internal_value

      CollectionWeapon.where(ax_modifier1_ref_id: modifier.id)
                      .update_all(ax_modifier1: internal_value)
      CollectionWeapon.where(ax_modifier2_ref_id: modifier.id)
                      .update_all(ax_modifier2: internal_value)
      GridWeapon.where(ax_modifier1_ref_id: modifier.id)
                .update_all(ax_modifier1: internal_value)
      GridWeapon.where(ax_modifier2_ref_id: modifier.id)
                .update_all(ax_modifier2: internal_value)
    end
  end
end
