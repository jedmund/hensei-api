# frozen_string_literal: true

class RemoveStaleHeedDaRows < ActiveRecord::Migration[8.0]
  def up
    WeaponSkillDatum.where(
      modifier: "Heed",
      boost_type: "da",
      weapon_skill_version_id: nil
    ).where.not(series: "normal_omega", size: "small").delete_all
  end

  def down
    # The removed row was stale local curation and is intentionally not restored.
  end
end
