# frozen_string_literal: true

# Normalizes empty ring/earring JSONB columns to NULL on both grid_characters
# and collection_characters.
#
# Historically these columns held a mix of representations for "unset":
#   - NULL (correct)
#   - {modifier: nil, strength: nil} (returned from apply_new_rings padding)
#   - {modifier: 1, strength: 0} (placeholder leaked from the edit pane bug
#     fixed in the frontend hensei-web#856)
#   - {modifier: 0, strength: 0}
#
# After the blueprint consolidation that makes both grid and collection
# characters expose the same positional `over_mastery` array, per-field sync
# writes the raw column value across without normalizing — so we want the
# column itself to consistently store NULL for empty slots.
#
# Rule: a ring/earring is considered empty when:
#   - the column is already NULL, OR
#   - modifier is missing / nil / 0, OR
#   - strength is missing / nil / 0
# These cases collapse to NULL.
class NormalizeEmptyRingsToNull < ActiveRecord::Migration[8.0]
  RING_COLUMNS = %i[ring1 ring2 ring3 ring4 earring].freeze

  def up
    [
      ['grid_characters', GridCharacter],
      ['collection_characters', CollectionCharacter]
    ].each do |table, klass|
      RING_COLUMNS.each do |column|
        # Use a JSONB-aware predicate so we only rewrite rows whose value
        # currently encodes an "empty" ring, leaving anything well-formed alone.
        sql = <<~SQL.squish
          UPDATE #{table}
          SET #{column} = NULL
          WHERE #{column} IS NOT NULL
            AND (
              #{column} ->> 'modifier' IS NULL
              OR (#{column} ->> 'modifier')::int = 0
              OR #{column} ->> 'strength' IS NULL
              OR (#{column} ->> 'strength')::int = 0
            )
        SQL

        rows = klass.connection.execute(sql).cmd_tuples
        say "Normalized #{rows} rows on #{table}.#{column}", true
      end
    end
  end

  def down
    # Irreversible: we lose the distinction between "explicitly cleared" and
    # "never set" representations. Both map to NULL going forward.
    raise ActiveRecord::IrreversibleMigration
  end
end
