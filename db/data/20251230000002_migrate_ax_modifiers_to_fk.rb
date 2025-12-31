# frozen_string_literal: true

class MigrateAxModifiersToFk < ActiveRecord::Migration[8.0]
  def up
    # Build lookup cache: game_skill_id -> weapon_stat_modifier.id
    modifier_lookup = WeaponStatModifier.pluck(:game_skill_id, :id).to_h

    # Migrate CollectionWeapon ax_modifier1
    CollectionWeapon.where.not(ax_modifier1: nil).find_each do |cw|
      modifier_id = modifier_lookup[cw.ax_modifier1]
      if modifier_id
        cw.update_columns(ax_modifier1_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier1=#{cw.ax_modifier1} on CollectionWeapon##{cw.id}"
      end
    end

    # Migrate CollectionWeapon ax_modifier2
    CollectionWeapon.where.not(ax_modifier2: nil).find_each do |cw|
      modifier_id = modifier_lookup[cw.ax_modifier2]
      if modifier_id
        cw.update_columns(ax_modifier2_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier2=#{cw.ax_modifier2} on CollectionWeapon##{cw.id}"
      end
    end

    # Migrate GridWeapon ax_modifier1
    GridWeapon.where.not(ax_modifier1: nil).find_each do |gw|
      modifier_id = modifier_lookup[gw.ax_modifier1]
      if modifier_id
        gw.update_columns(ax_modifier1_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier1=#{gw.ax_modifier1} on GridWeapon##{gw.id}"
      end
    end

    # Migrate GridWeapon ax_modifier2
    GridWeapon.where.not(ax_modifier2: nil).find_each do |gw|
      modifier_id = modifier_lookup[gw.ax_modifier2]
      if modifier_id
        gw.update_columns(ax_modifier2_ref_id: modifier_id)
      else
        Rails.logger.warn "[MigrateAxModifiers] Unknown ax_modifier2=#{gw.ax_modifier2} on GridWeapon##{gw.id}"
      end
    end
  end

  def down
    # Reverse: copy FK back to integer columns
    WeaponStatModifier.find_each do |modifier|
      next unless modifier.game_skill_id

      CollectionWeapon.where(ax_modifier1_ref_id: modifier.id)
                      .update_all(ax_modifier1: modifier.game_skill_id)
      CollectionWeapon.where(ax_modifier2_ref_id: modifier.id)
                      .update_all(ax_modifier2: modifier.game_skill_id)
      GridWeapon.where(ax_modifier1_ref_id: modifier.id)
                .update_all(ax_modifier1: modifier.game_skill_id)
      GridWeapon.where(ax_modifier2_ref_id: modifier.id)
                .update_all(ax_modifier2: modifier.game_skill_id)
    end
  end
end
