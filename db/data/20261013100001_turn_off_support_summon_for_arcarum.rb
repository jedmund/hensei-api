# frozen_string_literal: true

# Turns off the support summon for Arcarum groups: Evoking Solomonis (found by
# its content mode) and the Sandbox groups below (found by English name).
# Only ever turns the flag off, so rerunning it keeps edits that turn it back
# on elsewhere; a group that isn't in this database is skipped.
class TurnOffSupportSummonForArcarum < ActiveRecord::Migration[8.1]
  GROUP_NAMES_EN = ['Replicard Sandbox', 'Here Be Swords', 'Here Be Staves', 'Genesis Creationis'].freeze

  def up
    RaidGroup.reset_column_information
    RaidGroup.where(content_mode: RaidGroup::SOLOMONIS)
             .or(RaidGroup.where(name_en: GROUP_NAMES_EN))
             .update_all(support_summon: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
