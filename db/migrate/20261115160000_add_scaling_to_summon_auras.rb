# frozen_string_literal: true

# What an aura that scales with the main allies' weapon groups gives (Grand Order): each
# per-group effect with its cap, and the group count that unlocks a bonus. Written by the
# summon aura build.
class AddScalingToSummonAuras < ActiveRecord::Migration[8.1]
  def change
    add_column :summon_auras, :scaling, :jsonb
  end
end
