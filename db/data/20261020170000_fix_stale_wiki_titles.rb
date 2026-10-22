# frozen_string_literal: true

# Points wiki_en at the gbf.wiki pages these weapons and characters live on now, matched by
# game id against the wiki's Cargo tables. The old titles aren't Cargo pages, so wiki
# exports and lookups by title missed them: Eternal weapon variants are named by color
# (Incendo/Cardinal), Touken Ranbu and Raphael weapon pages carry "(Weapon)", and a few
# characters dropped "(Grand)" or gained "(Promo)". Rows are matched on granblue_id and
# their current title, so style shifts sharing a granblue_id keep theirs; every row on the
# old title is retitled. Only wiki_en changes; names stay as they are.
#
# Rerunnable and atomic: everything runs in one transaction. A granblue_id with no row on
# either title is skipped and reported with say rather than raised, since this runs
# before every API deploy and a raise would block the release.
#
# The weapon-skill build reads a weapon's page from weapon_sources by wiki_en. Where the
# new page is already stored as a page the old one transcluded, it becomes that weapon's
# wiki_raw source, as a fresh fetch would store it, so the build keeps working without
# fetching from the wiki. A weapon with no stored copy keeps its sources as they are.
class FixStaleWikiTitles < ActiveRecord::Migration[8.0]
  WEAPONS = {
    '1040002500' => ['Seven-Star Sword (Element Changed)', 'Seven-Star Sword Incendo'],
    '1040003700' => ['Seven-Star Sword (Awakened)', 'Seven-Star Sword Cardinal'],
    '1040102300' => ['Four-Sky Blade (Element Changed)', 'Four-Sky Blade Incendo'],
    '1040103100' => ['Four-Sky Blade (Awakened)', 'Four-Sky Blade Cardinal'],
    '1040202200' => ['One-Rift Spear (Element Changed)', 'One-Rift Spear Incendo'],
    '1040203100' => ['One-Rift Spear (Awakened)', 'One-Rift Spear Cardinal'],
    '1040301700' => ['Three-Tiger Axe (Element Changed)', 'Three-Tiger Axe Incendo'],
    '1040302400' => ['Three-Tiger Axe (Awakened)', 'Three-Tiger Axe Cardinal'],
    '1040402100' => ['Five-Soul Staff (Element Changed)', 'Five-Soul Staff Incendo'],
    '1040403100' => ['Five-Soul Staff (Awakened)', 'Five-Soul Staff Cardinal'],
    '1040501000' => ['Ten-Wolf Gun (Element Changed)', 'Ten-Wolf Gun Incendo'],
    '1040501700' => ['Ten-Wolf Gun (Awakened)', 'Ten-Wolf Gun Cardinal'],
    '1040601100' => ['Six-Ruin Fist (Element Changed)', 'Six-Ruin Fist Incendo'],
    '1040601800' => ['Six-Ruin Fist (Awakened)', 'Six-Ruin Fist Cardinal'],
    '1040701100' => ['Two-Crown Bow (Element Changed)', 'Two-Crown Bow Incendo'],
    '1040701800' => ['Two-Crown Bow (Awakened)', 'Two-Crown Bow Cardinal'],
    '1040800500' => ['Nine-Realm Harp (Element Changed)', 'Nine-Realm Harp Incendo'],
    '1040801400' => ['Nine-Realm Harp (Awakened)', 'Nine-Realm Harp Cardinal'],
    '1040900700' => ['Eight-Life Katana (Element Changed)', 'Eight-Life Katana Incendo'],
    '1040901400' => ['Eight-Life Katana (Awakened)', 'Eight-Life Katana Cardinal'],
    '1030902400' => ['Honebami Toushirou (NPC)', 'Honebami Toushirou (Weapon)'],
    '1030902500' => ['Mutsunokami Yoshiyuki (NPC)', 'Mutsunokami Yoshiyuki (Weapon)'],
    '1030902600' => ['Izuminokami Kanesada', 'Izuminokami Kanesada (Weapon)'],
    '1030902700' => ['Yamanbagiri Kunihiro', 'Yamanbagiri Kunihiro (Weapon)'],
    '1040505700' => ['Raphael', 'Raphael (Weapon)'],
    '1040908200' => ['Mikazuki Munechika', 'Mikazuki Munechika (Weapon)'],
    '1040908300' => ['Tsurumaru Kuninaga (NPC)', 'Tsurumaru Kuninaga (Weapon)']
  }.freeze

  CHARACTERS = {
    '3030143000' => ['Augusta', 'Augusta (Promo)'],
    '3030145000' => ['Pamela', 'Pamela (Promo)'],
    '3030146000' => ['Cecile', 'Cecile (Promo)'],
    '3040486000' => ['Kaguya (Grand)', 'Kaguya'],
    '3040501000' => ['Uriel (Grand)', 'Uriel'],
    '3040515000' => ['Sandalphon (Grand)', 'Sandalphon'],
    '3040519000' => ['Fenie (Grand)', 'Fenie']
  }.freeze

  def up
    transaction do
      weapons = retitle(Weapon, WEAPONS)
      characters = retitle(Character, CHARACTERS)
      promoted = weapons.count { |weapon| promote_stored_page(weapon) }
      say "weapons.wiki_en: #{weapons.size} retitled, #{promoted} stored pages became wiki_raw sources"
      say "characters.wiki_en: #{characters.size} retitled"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Retitles every row still on its old title and returns them. An id with no row on
  # either title is skipped and reported.
  def retitle(model, titles)
    titles.flat_map do |granblue_id, (from, to)|
      found = model.where(granblue_id: granblue_id, wiki_en: from).to_a
      if found.empty? && !model.exists?(granblue_id: granblue_id, wiki_en: to)
        say "Skipped #{model.name} #{granblue_id}: no row titled #{from.inspect} or #{to.inspect}"
      end
      found.each { |row| row.update_columns(wiki_en: to) }
    end
  end

  # Returns whether the weapon's new page was stored and is now its wiki_raw source.
  def promote_stored_page(weapon) # rubocop:disable Naming/PredicateMethod
    page = WeaponSource.find_by(weapon_id: weapon.id, kind: 'transclusion', key: weapon.wiki_en)
    return false unless page

    WeaponSource.where(weapon_id: weapon.id, kind: 'wiki_raw').delete_all
    WeaponSkills::SourceStore::Database.new.put(
      'wiki_raw', weapon.wiki_en, page.body,
      page_kind: WeaponSkills::SourceStore::Fetcher.page_kind(page.body),
      fetched_at: page.fetched_at, weapon_id: weapon.id
    )
    page.destroy!
    Source.put(weapon, :wiki_raw, page.body, fetched_at: page.fetched_at)
    true
  end
end
