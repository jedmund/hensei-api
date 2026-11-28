# frozen_string_literal: true

# A spark can mark more than one item as sparked. The marks move from the
# single sparked_column/sparked_index pair to a list; the old columns stay
# (ignored by the model) until a later migration drops them, so the app
# serving during this deploy keeps working.
class AddSparkedMarksToSavedSparks < ActiveRecord::Migration[8.1]
  def up
    add_column :saved_sparks, :sparked_marks, :jsonb, null: false, default: []

    execute <<~SQL.squish
      UPDATE saved_sparks
      SET sparked_marks = jsonb_build_array(jsonb_build_object('column', sparked_column, 'index', sparked_index))
      WHERE sparked_column IS NOT NULL AND sparked_index IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE saved_sparks
      SET sparked_column = sparked_marks -> 0 ->> 'column',
          sparked_index = (sparked_marks -> 0 ->> 'index')::integer
      WHERE jsonb_array_length(sparked_marks) > 0
    SQL

    remove_column :saved_sparks, :sparked_marks
  end
end
