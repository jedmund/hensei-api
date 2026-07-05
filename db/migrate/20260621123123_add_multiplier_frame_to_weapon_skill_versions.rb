# frozen_string_literal: true

class AddMultiplierFrameToWeaponSkillVersions < ActiveRecord::Migration[8.0]
  def change
    # The authoritative damage frame from the wiki "Multiplier:" annotation captured during
    # template expansion. Preferred over the heuristic skill_series, which the description
    # extractor re-derives and may get wrong for aura-word-less skills (e.g. Guiding Star).
    add_column :weapon_skill_versions, :multiplier_frame, :string
  end
end
