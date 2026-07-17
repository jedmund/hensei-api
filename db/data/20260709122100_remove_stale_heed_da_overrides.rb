# frozen_string_literal: true

class RemoveStaleHeedDaOverrides < ActiveRecord::Migration[8.0]
  def up
    keep = WeaponSkillDatum.where(
      modifier: "Heed",
      boost_type: "da",
      series: "normal_omega",
      size: "small",
      weapon_skill_version_id: nil
    ).select(:id)

    WeaponSkillDatum.where(modifier: "Heed", boost_type: "da").where.not(id: keep).delete_all
  end

  def down
    # Removed rows were stale description-derived overrides and are intentionally not restored.
  end
end
