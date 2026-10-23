# frozen_string_literal: true

# The six Ancient (olden primal) weapons were marked ax_type 'utility', which only
# allows a single EXP/Rupie AX slot. Live game data shows them carrying primary AX
# skills (e.g. Ancient Perseus with HP +9%), so AX validation rejected real imports.
# Clearing the column lets Weapon#effective_ax_type derive 'primal' from the series,
# which allows both primary and utility skills.
class ClearAncientWeaponUtilityAxType < ActiveRecord::Migration[8.0]
  GRANBLUE_IDS = %w[
    1040803500
    1040604000
    1040703400
    1040106400
    1040205200
    1040007000
  ].freeze

  def up
    Weapon.where(granblue_id: GRANBLUE_IDS, ax_type: 'utility').update_all(ax_type: nil)
  end

  def down
    Weapon.where(granblue_id: GRANBLUE_IDS, ax_type: nil).update_all(ax_type: 'utility')
  end
end
