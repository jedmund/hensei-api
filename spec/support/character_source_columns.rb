# frozen_string_literal: true

# The characters source columns were dropped (20261022090000). Specs for the data migrations
# that read them re-add them, empty, for the example (the DDL rolls back with it).
module CharacterSourceColumns
  def self.included(group)
    group.before do
      require Rails.root.join('db/migrate/20261022090000_drop_character_source_columns')
      DropCharacterSourceColumns.new.tap { |m| m.verbose = false }.down
    end
    group.after { Character.reset_column_information }
  end
end
