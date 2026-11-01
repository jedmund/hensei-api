# frozen_string_literal: true

# Blank weapon text fields become NULL, so "no value" has one spelling and the editor's
# missing-value filters and the API stop telling '' and null apart. Most are wiki_ja,
# gamewith and kamigame left as '' by their column defaults.
#
# update_all writes the columns alone: no callbacks, no skill builds. updated_at is set
# with them, like the other bulk catalogue writes, because the admin list's ETag keys on
# it and the rows now serialize differently. Rerunnable: cleared rows no longer match.
class NullBlankWeaponTextFields < ActiveRecord::Migration[8.1]
  COLUMNS = %i[wiki_en wiki_ja gamewith kamigame name_jp recruits forged_from].freeze

  def up
    weapons = Class.new(ActiveRecord::Base) { self.table_name = 'weapons' }
    now = Time.current

    COLUMNS.each do |column|
      count = weapons.where(column => '').update_all(column => nil, updated_at: now)
      say "weapons.#{column}: #{count} blank values set to NULL"
    end
  end

  def down
    # Nothing to undo: NULL and '' both mean no value.
  end
end
