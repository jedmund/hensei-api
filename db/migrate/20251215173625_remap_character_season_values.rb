# frozen_string_literal: true

# Remap character season values after removing "Standard" season.
# Old values: Standard=1, Valentine=2, Formal=3, Summer=4, Halloween=5, Holiday=6
# New values: Valentine=1, Formal=2, Summer=3, Halloween=4, Holiday=5
#
# Uses negative temporary values to avoid conflicts during remapping.
class RemapCharacterSeasonValues < ActiveRecord::Migration[8.0]
  def up
    # First, remap all values to negative temporaries to avoid conflicts
    execute "UPDATE characters SET season = -2 WHERE season = 2"  # Valentine -> temp
    execute "UPDATE characters SET season = -3 WHERE season = 3"  # Formal -> temp
    execute "UPDATE characters SET season = -4 WHERE season = 4"  # Summer -> temp
    execute "UPDATE characters SET season = -5 WHERE season = 5"  # Halloween -> temp
    execute "UPDATE characters SET season = -6 WHERE season = 6"  # Holiday -> temp

    # Remove Standard (1 -> NULL)
    execute "UPDATE characters SET season = NULL WHERE season = 1"

    # Now remap from temporaries to final values
    execute "UPDATE characters SET season = 1 WHERE season = -2"  # Valentine: 2 -> 1
    execute "UPDATE characters SET season = 2 WHERE season = -3"  # Formal: 3 -> 2
    execute "UPDATE characters SET season = 3 WHERE season = -4"  # Summer: 4 -> 3
    execute "UPDATE characters SET season = 4 WHERE season = -5"  # Halloween: 5 -> 4
    execute "UPDATE characters SET season = 5 WHERE season = -6"  # Holiday: 6 -> 5
  end

  def down
    # Remap back to original values using negative temporaries
    execute "UPDATE characters SET season = -1 WHERE season = 1"  # Valentine -> temp
    execute "UPDATE characters SET season = -2 WHERE season = 2"  # Formal -> temp
    execute "UPDATE characters SET season = -3 WHERE season = 3"  # Summer -> temp
    execute "UPDATE characters SET season = -4 WHERE season = 4"  # Halloween -> temp
    execute "UPDATE characters SET season = -5 WHERE season = 5"  # Holiday -> temp

    # Remap to original values (Standard cannot be restored from NULL)
    execute "UPDATE characters SET season = 2 WHERE season = -1"  # Valentine: 1 -> 2
    execute "UPDATE characters SET season = 3 WHERE season = -2"  # Formal: 2 -> 3
    execute "UPDATE characters SET season = 4 WHERE season = -3"  # Summer: 3 -> 4
    execute "UPDATE characters SET season = 5 WHERE season = -4"  # Halloween: 4 -> 5
    execute "UPDATE characters SET season = 6 WHERE season = -5"  # Holiday: 5 -> 6
  end
end
