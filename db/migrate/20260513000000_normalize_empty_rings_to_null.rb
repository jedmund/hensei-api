# frozen_string_literal: true

# Normalizes empty ring/earring JSONB columns to the canonical empty hash
# `{"modifier": null, "strength": null}` on both grid_characters and
# collection_characters.
#
# Historically these columns held a mix of representations for "unset":
#   - {modifier: nil, strength: nil} (the canonical empty — column default and
#     what apply_new_rings / reset_rings write)
#   - {modifier: 1, strength: 0} (placeholder leaked from the edit pane bug
#     fixed in the frontend hensei-web#856)
#   - {modifier: 0, strength: 0}
#
# After the blueprint consolidation that makes both grid and collection
# characters expose the same positional `over_mastery` array, per-field sync
# writes the raw column value across without normalizing — so we want every
# empty slot to store the SAME canonical hash.
#
# We collapse to the canonical hash rather than SQL NULL because the columns are
# NOT NULL and, more importantly, the model's over-mastery validations
# (over_mastery_attack, validate_over_mastery_attack_matches_hp,
# validate_aetherial_mastery_value, ...) index into the ring hash directly and
# would raise on a NULL value. Api::V1::CollectionCharacterBlueprint.serialize_ring
# already renders this canonical hash as `null`, so the API output is unchanged.
#
# Rule: a ring/earring is considered empty when:
#   - modifier is missing / nil / 0, OR
#   - strength is missing / nil / 0
# These cases collapse to {"modifier": null, "strength": null}.
class NormalizeEmptyRingsToNull < ActiveRecord::Migration[8.0]
  RING_COLUMNS = %i[ring1 ring2 ring3 ring4 earring].freeze
  CANONICAL_EMPTY = '{"modifier": null, "strength": null}'

  def up
    [
      ['grid_characters', GridCharacter],
      ['collection_characters', CollectionCharacter]
    ].each do |table, klass|
      RING_COLUMNS.each do |column|
        # Use a JSONB-aware predicate so we only rewrite rows whose value
        # currently encodes an "empty" ring in some non-canonical form, leaving
        # already-canonical empties and well-formed rings untouched.
        sql = <<~SQL.squish
          UPDATE #{table}
          SET #{column} = '#{CANONICAL_EMPTY}'::jsonb
          WHERE #{column} IS DISTINCT FROM '#{CANONICAL_EMPTY}'::jsonb
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
    # Irreversible: we lose the distinction between the various "empty"
    # representations. All map to the canonical empty hash going forward.
    raise ActiveRecord::IrreversibleMigration
  end
end
