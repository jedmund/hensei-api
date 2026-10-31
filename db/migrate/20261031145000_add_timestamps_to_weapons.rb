# frozen_string_literal: true

# The admin weapon collection (GBF-138) lists, filters and sorts by
# updated_at, and its ETag is keyed on it. Existing rows get the migration
# time; the database default keeps raw-SQL writers working.
class AddTimestampsToWeapons < ActiveRecord::Migration[8.1]
  def change
    add_timestamps :weapons, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    add_index :weapons, :updated_at
  end
end
