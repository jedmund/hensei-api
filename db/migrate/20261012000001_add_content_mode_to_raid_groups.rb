# frozen_string_literal: true

# Tells the web app which special content a raid group's parties carry.
# `solomonis` marks Evoking Solomonis; null is an ordinary group. A string
# rather than another boolean beside `guidebooks`, `extra` and `unlimited`.
class AddContentModeToRaidGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :raid_groups, :content_mode, :string
    add_index :raid_groups, :content_mode
  end
end
