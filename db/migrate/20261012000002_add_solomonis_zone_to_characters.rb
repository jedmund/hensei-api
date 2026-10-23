# frozen_string_literal: true

# The Evoking Solomonis zone (a raid in the Solomonis group) an Evoker's
# expedition runs in. A character with a zone is a route-eligible Evoker.
class AddSolomonisZoneToCharacters < ActiveRecord::Migration[8.1]
  def change
    add_reference :characters, :solomonis_zone, type: :uuid, foreign_key: { to_table: :raids }, index: true
  end
end
