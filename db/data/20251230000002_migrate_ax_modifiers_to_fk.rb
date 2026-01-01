# frozen_string_literal: true

class MigrateAxModifiersToFk < ActiveRecord::Migration[8.0]
  # Old AX_MAPPING from WeaponProcessor stored internal integer values (0, 1, 2...)
  # We need to map: old internal_value => game_skill_id => weapon_stat_modifier.id
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
    # Build lookup: old_internal_value -> new FK id
    modifier_by_game_skill_id = WeaponStatModifier.pluck(:game_skill_id, :id).to_h
    old_to_new_id = OLD_INTERNAL_TO_GAME_SKILL_ID.transform_values do |game_skill_id|
      modifier_by_game_skill_id[game_skill_id]
    end

    # Use raw SQL to query old integer columns (ax_modifier1, ax_modifier2)
    # and update the new FK columns (ax_modifier1_id, ax_modifier2_id)

    # Migrate CollectionWeapon
    execute <<-SQL.squish
      UPDATE collection_weapons
      SET ax_modifier1_id = CASE ax_modifier1
        #{old_to_new_id.map { |old_val, new_id| "WHEN #{old_val} THEN #{new_id}" }.join(' ')}
      END
      WHERE ax_modifier1 IS NOT NULL
    SQL

    execute <<-SQL.squish
      UPDATE collection_weapons
      SET ax_modifier2_id = CASE ax_modifier2
        #{old_to_new_id.map { |old_val, new_id| "WHEN #{old_val} THEN #{new_id}" }.join(' ')}
      END
      WHERE ax_modifier2 IS NOT NULL
    SQL

    # Migrate GridWeapon
    execute <<-SQL.squish
      UPDATE grid_weapons
      SET ax_modifier1_id = CASE ax_modifier1
        #{old_to_new_id.map { |old_val, new_id| "WHEN #{old_val} THEN #{new_id}" }.join(' ')}
      END
      WHERE ax_modifier1 IS NOT NULL
    SQL

    execute <<-SQL.squish
      UPDATE grid_weapons
      SET ax_modifier2_id = CASE ax_modifier2
        #{old_to_new_id.map { |old_val, new_id| "WHEN #{old_val} THEN #{new_id}" }.join(' ')}
      END
      WHERE ax_modifier2 IS NOT NULL
    SQL
  end

  def down
    # Build reverse lookup: new FK id -> old internal value
    modifier_by_game_skill_id = WeaponStatModifier.pluck(:game_skill_id, :id).to_h
    game_skill_id_to_internal = OLD_INTERNAL_TO_GAME_SKILL_ID.invert
    new_id_to_old = modifier_by_game_skill_id.each_with_object({}) do |(game_skill_id, new_id), hash|
      old_val = game_skill_id_to_internal[game_skill_id]
      hash[new_id] = old_val if old_val
    end

    return if new_id_to_old.empty?

    # Reverse: copy FK back to old integer columns
    execute <<-SQL.squish
      UPDATE collection_weapons
      SET ax_modifier1 = CASE ax_modifier1_id
        #{new_id_to_old.map { |new_id, old_val| "WHEN #{new_id} THEN #{old_val}" }.join(' ')}
      END
      WHERE ax_modifier1_id IS NOT NULL
    SQL

    execute <<-SQL.squish
      UPDATE collection_weapons
      SET ax_modifier2 = CASE ax_modifier2_id
        #{new_id_to_old.map { |new_id, old_val| "WHEN #{new_id} THEN #{old_val}" }.join(' ')}
      END
      WHERE ax_modifier2_id IS NOT NULL
    SQL

    execute <<-SQL.squish
      UPDATE grid_weapons
      SET ax_modifier1 = CASE ax_modifier1_id
        #{new_id_to_old.map { |new_id, old_val| "WHEN #{new_id} THEN #{old_val}" }.join(' ')}
      END
      WHERE ax_modifier1_id IS NOT NULL
    SQL

    execute <<-SQL.squish
      UPDATE grid_weapons
      SET ax_modifier2 = CASE ax_modifier2_id
        #{new_id_to_old.map { |new_id, old_val| "WHEN #{new_id} THEN #{old_val}" }.join(' ')}
      END
      WHERE ax_modifier2_id IS NOT NULL
    SQL
  end
end
