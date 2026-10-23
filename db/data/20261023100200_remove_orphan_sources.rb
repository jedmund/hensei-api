# frozen_string_literal: true

# Removes `sources` rows whose owner is gone. weapon_sources had a foreign key that removed a
# weapon's rows with it; `sources` is polymorphic and has none, so a weapon, summon or
# character deleted with SQL (not destroy, which removes its rows) leaves its rows behind.
# Shared rows (no owner) stay. Idempotent; counts only. Sources::OrphanCleanup does the same on
# demand (bin/rails granblue:remove_orphan_sources).
class RemoveOrphanSources < ActiveRecord::Migration[8.1]
  OWNERS = { 'Character' => 'characters', 'Weapon' => 'weapons', 'Summon' => 'summons' }.freeze

  def up
    OWNERS.each do |owner_type, table|
      removed = connection.exec_delete(<<~SQL.squish)
        DELETE FROM sources s
        WHERE s.owner_type = #{connection.quote(owner_type)}
          AND NOT EXISTS (SELECT 1 FROM #{table} o WHERE o.id = s.owner_id)
      SQL
      say "#{owner_type}: #{removed} orphan source rows removed"
    end
  end

  def down
    # Nothing to restore: their owners are gone.
  end
end
