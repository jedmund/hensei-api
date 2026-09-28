# frozen_string_literal: true

# Duplicated and remixed parties stored their characters' rings and earring as
# the jsonb *string* "{modifier: nil, strength: nil}" (amoeba's `set` calls to_s).
# Over mastery validation raises on those rows, so every later update to the
# character returned a 500. Every such value came from that reset, so all of
# them mean "empty": rewrite them to the canonical empty hash.
class RepairStringifiedGridCharacterRings < ActiveRecord::Migration[8.0]
  RING_COLUMNS = %i[ring1 ring2 ring3 ring4 earring].freeze
  CANONICAL_EMPTY = '{"modifier": null, "strength": null}'

  def up
    RING_COLUMNS.each do |column|
      rows = GridCharacter.connection.execute(<<~SQL.squish).cmd_tuples
        UPDATE grid_characters
        SET #{column} = '#{CANONICAL_EMPTY}'::jsonb
        WHERE jsonb_typeof(#{column}) = 'string'
      SQL
      say "Repaired #{rows} rows on grid_characters.#{column}", true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
