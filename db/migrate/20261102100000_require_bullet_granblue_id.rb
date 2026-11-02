# frozen_string_literal: true

# Every bullet has a Granblue ID (all 116 in production), and the database
# editor addresses bullets by it, so the column can no longer be blank.
class RequireBulletGranblueId < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bullets, :granblue_id, false
  end
end
