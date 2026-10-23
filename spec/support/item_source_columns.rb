# frozen_string_literal: true

# The weapons/summons source columns and weapon_sources were dropped (20261023100000). Specs for
# the data migrations that read them re-add them, empty, for the example (the DDL rolls back
# with it).
module ItemSourceColumns
  def self.included(group)
    group.before do
      require Rails.root.join('db/migrate/20261023100000_drop_item_source_columns')
      DropItemSourceColumns.new.tap { |m| m.verbose = false }.down
      [Weapon, Summon].each(&:reset_column_information)
    end
    group.after { [Weapon, Summon].each(&:reset_column_information) }
  end
end
