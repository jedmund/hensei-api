# frozen_string_literal: true

# Stores gbf.wiki titles in MediaWiki's canonical form (Granblue::WikiTitle): about 100
# weapons, 5 characters and a summon had percent-encoded titles ("Devil%27s Finger"), which
# the web encoded again into broken links, and others mixed underscores and spaces. The
# models normalize wiki_en from now on; this fixes existing rows, and the weapon_sources
# keys that name the same pages. Where two stored sources normalize to the same title, the
# newest is kept.
class NormalizeWikiTitles < ActiveRecord::Migration[8.0]
  def up
    [Weapon, Summon, Character].each do |model|
      changed = 0
      model.where.not(wiki_en: nil).pluck(:id, :wiki_en).each do |id, title|
        normalized = Granblue::WikiTitle.normalize(title)
        next if normalized == title

        model.where(id: id).update_all(wiki_en: normalized)
        changed += 1
      end
      say "#{model.table_name}.wiki_en: #{changed} normalized"
    end

    normalize_source_keys
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def normalize_source_keys
    rows = WeaponSource.pluck(:id, :weapon_id, :kind, :key, :fetched_at)
    renamed = 0
    removed = 0
    rows.group_by { |_, weapon_id, kind, key, _| [weapon_id, kind, Granblue::WikiTitle.normalize(key)] }
        .each do |(_, _, normalized), group|
      keep, *older = group.sort_by { |row| row[4] }.reverse
      if older.any?
        WeaponSource.where(id: older.map(&:first)).delete_all
        removed += older.size
      end
      next if keep[3] == normalized

      WeaponSource.where(id: keep[0]).update_all(key: normalized)
      renamed += 1
    end
    say "weapon_sources keys: #{renamed} normalized, #{removed} duplicates removed"
  end
end
