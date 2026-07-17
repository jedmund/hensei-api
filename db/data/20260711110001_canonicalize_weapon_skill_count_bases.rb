# frozen_string_literal: true

class CanonicalizeWeaponSkillCountBases < ActiveRecord::Migration[8.0]
  COUNT_BASIS_RENAMES = {
    "weapon_type" => "same_weapon_type",
    "weapon_group" => "distinct_weapon_types",
    "weapon_series" => "same_series",
    "epic" => "series:epic",
    "militis" => "series:militis",
    "grand" => "series:grand"
  }.freeze

  def up
    COUNT_BASIS_RENAMES.each do |old_basis, new_basis|
      execute <<~SQL.squish
        UPDATE weapon_skill_effects
        SET count_basis = #{quote(new_basis)}
        WHERE count_basis = #{quote(old_basis)}
      SQL
    end

    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET condition = jsonb_build_object(
        'type', 'count_basis_gte',
        'basis', 'max_same_weapon_type',
        'gte', COALESCE(condition -> 'gte', '4'::jsonb)
      )
      WHERE condition ->> 'type' = 'same_weapon_type_count'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE weapon_skill_effects
      SET condition = jsonb_build_object(
        'type', 'same_weapon_type_count',
        'gte', COALESCE(condition -> 'gte', '4'::jsonb)
      )
      WHERE condition ->> 'type' = 'count_basis_gte'
        AND condition ->> 'basis' = 'max_same_weapon_type'
    SQL

    COUNT_BASIS_RENAMES.invert.each do |new_basis, old_basis|
      execute <<~SQL.squish
        UPDATE weapon_skill_effects
        SET count_basis = #{quote(old_basis)}
        WHERE count_basis = #{quote(new_basis)}
      SQL
    end
  end
end
