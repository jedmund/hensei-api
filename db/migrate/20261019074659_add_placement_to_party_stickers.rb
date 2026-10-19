# frozen_string_literal: true

# Where a sticker sits in the team's sticker area. `x` is a
# fraction of the area's horizontal range, `y` px from the area's top, and
# `rotation` the lean (degrees) it was dropped or moved with. All null for
# stickers given without a placement, which line up on their own.
class AddPlacementToPartyStickers < ActiveRecord::Migration[8.1]
  def change
    add_column :party_stickers, :x, :float
    add_column :party_stickers, :y, :float
    add_column :party_stickers, :rotation, :float
  end
end
