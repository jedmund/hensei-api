# frozen_string_literal: true

require_relative '../../lib/siero/rateup_identity'

class BackfillGachaRateupDrawableIdentity < ActiveRecord::Migration[8.0]
  def up
    say Siero::RateupIdentity.new(connection).backfill.inspect
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Preserve backfilled and new-only rate-up identities'
  end
end
