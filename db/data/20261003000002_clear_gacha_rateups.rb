# frozen_string_literal: true

# Saved Siero rate-ups are years old and still carry legacy gacha table
# references. Clearing them lets Siero read typed rate-ups only; users set
# fresh ones with /rateup.
class ClearGachaRateups < ActiveRecord::Migration[8.0]
  def up
    say "Deleted #{connection.delete('DELETE FROM gacha_rateups')} saved rate-ups"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Cleared rate-ups can only be restored from a backup.'
  end
end
