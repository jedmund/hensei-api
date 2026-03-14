# frozen_string_literal: true

class BackfillPartyBoost < ActiveRecord::Migration[7.1]
  def up
    Party.includes(summons: { summon: :summon_series }).find_each do |party|
      party.recompute_boost!
      party.recompute_side!
    end
  end

  def down
    Party.update_all(boost_mod: nil, boost_side: nil)
  end
end
