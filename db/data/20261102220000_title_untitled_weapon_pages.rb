# frozen_string_literal: true

# Titles every weapon page stored without the source store's fetch. An editor's wiki import
# saved a new weapon's page under key '', and the weapon-skill build only reads pages by title
# (wiki_en), so those weapons never built: every weapon added since 2026-10-19 had no skills
# (Ragnarok, Ewiyar-Pocus, Fugitive's Claw, Kumogirimaru, Escorting Arms). Weapon#wiki_raw now
# titles the row itself (HasSources titled: :wiki_en); this moves the rows saved before that.
# The deploy's build runs after the data migrations and builds them (new fingerprints).
#
# A weapon with no wiki_en, or that already has a titled page, keeps its row.
# Idempotent, SQL only, prints the weapons it titles.
class TitleUntitledWeaponPages < ActiveRecord::Migration[8.1]
  def up
    titled = connection.select_rows(<<~SQL.squish)
      UPDATE sources own
      SET key = w.wiki_en, updated_at = now()
      FROM weapons w
      WHERE own.owner_type = 'Weapon' AND own.owner_id = w.id
        AND own.kind = 'wiki_raw' AND own.key = ''
        AND w.wiki_en IS NOT NULL AND w.wiki_en <> ''
        AND NOT EXISTS (
          SELECT 1 FROM sources other
          WHERE other.owner_type = 'Weapon' AND other.owner_id = own.owner_id
            AND other.kind = 'wiki_raw' AND other.key <> ''
        )
      RETURNING w.granblue_id
    SQL
    ids = titled.map(&:first).sort
    say "weapon pages: #{ids.size} titled#{": #{ids.join(', ')}" if ids.any?}"
  end

  def down
    # Nothing to restore: the titled row is the weapon's page.
  end
end
