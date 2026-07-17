# frozen_string_literal: true

# Pools follow the game's skill-id ranges (the seed file's partition):
# primary 1588-1592, secondary 1593-1601, extended 1719-1722, utility 1837+.
# Ancient (vintage classic) weapons carry the single-slot utility type.
class BackfillAxGroups < ActiveRecord::Migration[8.0]
  GROUPS = {
    "primary"   => %w[ax_hp ax_atk ax_def ax_ca_dmg ax_multiattack],
    "secondary" => %w[ax_debuff_res ax_ele_atk ax_healing ax_da ax_ta ax_ca_cap ax_stamina ax_enmity],
    "extended"  => %w[ax_skill_supp ax_ca_supp ax_ele_dmg_red ax_na_cap],
    "utility"   => %w[ax_exp ax_rupie]
  }.freeze

  def up
    GROUPS.each do |group, slugs|
      WeaponStatModifier.where(slug: slugs).update_all(ax_group: group)
    end
    Weapon.where("weapons.name_en LIKE 'Ancient %'")
          .joins(:weapon_series).where(weapon_series: { slug: "primal" })
          .update_all(ax_type: "utility")
  end

  def down
    WeaponStatModifier.update_all(ax_group: nil)
    Weapon.update_all(ax_type: nil)
  end
end
