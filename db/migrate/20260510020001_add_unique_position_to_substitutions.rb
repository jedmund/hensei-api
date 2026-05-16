# frozen_string_literal: true

class AddUniquePositionToSubstitutions < ActiveRecord::Migration[8.0]
  def change
    # The original (grid_type, grid_id, substitute_grid_type, substitute_grid_id)
    # index cannot fire — substitute_grid_id is freshly generated on every insert,
    # so the tuple is unique by construction. Replace it with an index that
    # actually enforces the slot ordering invariant.
    remove_index :substitutions, name: 'index_substitutions_uniqueness'

    add_index :substitutions,
              %i[grid_type grid_id position],
              unique: true,
              name: 'index_substitutions_on_slot_position'
  end
end
