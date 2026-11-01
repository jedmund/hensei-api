# frozen_string_literal: true

# Blank weapon links are stored as NULL (see the 20261101120000 data migration), so new
# weapons shouldn't get '' from a column default either.
class DropBlankDefaultsFromWeaponLinks < ActiveRecord::Migration[8.1]
  COLUMNS = %i[wiki_en wiki_ja gamewith kamigame].freeze

  def change
    COLUMNS.each { |column| change_column_default :weapons, column, from: '', to: nil }
  end
end
