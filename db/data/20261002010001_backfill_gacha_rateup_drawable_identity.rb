# frozen_string_literal: true

# Backfilled typed rate-up identities from the legacy gacha table. The saved
# rate-ups were later cleared (ClearGachaRateups) and the table dropped
# (DropLegacyGachaSchema), so this is kept as a no-op for migration history.
class BackfillGachaRateupDrawableIdentity < ActiveRecord::Migration[8.0]
  def up; end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Preserve backfilled and new-only rate-up identities'
  end
end
