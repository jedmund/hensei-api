# frozen_string_literal: true

# AX skills roll from pools ("groups"), and a weapon's AX type decides which pool
# each of its slots draws from. Until now the frontend hardcoded the split and a
# utility-type weapon (Ancient Cortana: one slot, EXP/Rupie only) couldn't be
# represented at all.
class AddAxGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :weapon_stat_modifiers, :ax_group, :string
    add_column :weapons, :ax_type, :string
  end
end
