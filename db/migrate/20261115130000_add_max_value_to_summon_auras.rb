# frozen_string_literal: true

# An aura's stated maximum ("40% boost to Normal ATK (Max: 200%) for each weapon group"),
# so `value` always holds the amount the text gives and `max_value` its cap. Written by the
# summon aura build.
class AddMaxValueToSummonAuras < ActiveRecord::Migration[8.1]
  def change
    add_column :summon_auras, :max_value, :decimal
  end
end
