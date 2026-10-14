# frozen_string_literal: true

# Whether a raid group's fights take a support (friend) summon. Arcarum
# content, Evoking Solomonis included, is single-player and has none; the web
# app shows that slot disabled.
class AddSupportSummonToRaidGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :raid_groups, :support_summon, :boolean, null: false, default: true
  end
end
