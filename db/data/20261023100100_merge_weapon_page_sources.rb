# frozen_string_literal: true

# One stored page per weapon (PR 7b follow-up). A weapon kept its page twice: its own wiki_raw
# (key '') and the weapon-skill store's copy keyed by the page title, written together by every
# fetch. The titled row is now the weapon's page (Weapon#wiki_raw reads it), so the '' row of
# every weapon that has a titled one is removed. Where the two differ the titled row stays, as
# it's the one the build reads; those are counted. A weapon with only a '' row (a page stored
# without a store fetch) keeps it. Store rows don't change, so weapon fingerprints don't either.
#
# Idempotent, SQL only, counts only.
class MergeWeaponPageSources < ActiveRecord::Migration[8.1]
  def up
    removed = connection.select_rows(<<~SQL.squish)
      DELETE FROM sources own
      USING sources titled
      WHERE own.owner_type = 'Weapon' AND own.kind = 'wiki_raw' AND own.key = ''
        AND titled.owner_type = 'Weapon' AND titled.owner_id = own.owner_id
        AND titled.kind = 'wiki_raw' AND titled.key <> ''
      RETURNING (own.sha256 = titled.sha256)
    SQL
    same = removed.count { |(equal)| [true, 't'].include?(equal) }
    untitled = connection.select_value(<<~SQL.squish)
      SELECT count(*) FROM sources WHERE owner_type = 'Weapon' AND kind = 'wiki_raw' AND key = ''
    SQL
    say "weapon pages: #{removed.size} duplicate rows removed (#{same} same as the titled page, " \
        "#{removed.size - same} different), #{untitled} weapons with only an untitled page"
  end

  def down
    # Nothing to restore: the titled row holds the page.
  end
end
