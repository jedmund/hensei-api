# frozen_string_literal: true

# Draconic Bow was stored as a 3★ weapon (no FLB/ULB, level 100, SL10). Every Draconic
# weapon uncaps to 5★ (level 200, SL20): its wiki page and the FLB/ULB stats and dates
# already stored on the row say so. With the flags off, a grid copy can't go above 3★, so
# its Telumas (unlocked at 4★ and 5★) never apply and its skills read at SL10.
class UncapDraconicBow < ActiveRecord::Migration[8.0]
  GRANBLUE_ID = '1040709600'

  def up
    Weapon.where(granblue_id: GRANBLUE_ID, flb: false, ulb: false)
          .update_all(flb: true, ulb: true, max_level: 200, max_skill_level: 20, updated_at: Time.current)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'the old values were wrong'
  end
end
