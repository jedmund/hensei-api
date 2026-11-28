# frozen_string_literal: true

# Corrects characters whose names or wiki pages pointed at another version,
# checked against gbf.wiki's characters table (by game id) on 2026-11-28:
#
#   3040256000 Danua, Light (2020)        wiki_en "Danua (SSR)" → "Danua (Light)"
#   3040145000 Olivia, Grand Dark (2017)  wiki_en "Olivia" → "Olivia (Grand)"
#   3040442000 Friday, Wind SSR (2022)    name "Ultimate Friday" → "Friday" (Ｕ・フライデー
#                                         in Japanese, as the wiki has it), her only SSR
#   3030271000 Friday, Summer SR (2019)   wiki_en "Ultimate Friday" → "Friday (Summer)",
#                                         release 2022-12-31 → 2019-07-17
#
# Danua 3040616000 ("Danua (SSR)") and Olivia 3040508000 ("Olivia") already
# had their own pages. Each mistaken row had cached the other character's
# wiki page (its infobox id is the other one's), so that cache goes: the next
# wiki fetch for these characters brings their own page.
class FixDanuaOliviaFridayWikiPages < ActiveRecord::Migration[8.1]
  FIXES = {
    '3040256000' => { wiki_en: 'Danua (Light)' },
    '3040145000' => { wiki_en: 'Olivia (Grand)' },
    '3040442000' => { name_en: 'Friday', name_jp: 'Ｕ・フライデー' },
    '3030271000' => { wiki_en: 'Friday (Summer)', release_date: Date.new(2019, 7, 17) }
  }.freeze

  def up
    FIXES.each do |granblue_id, attributes|
      character = Character.find_by(granblue_id: granblue_id)
      next say("#{granblue_id}: not found") unless character

      changed = attributes.reject { |attribute, value| character[attribute] == value }
      character.update!(changed) if changed.any?
      foreign = foreign_wiki_page(character)
      foreign&.destroy!
      say "#{granblue_id}: #{changed.keys.join(', ').presence || 'already right'}#{', cached page of another character removed' if foreign}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # The character's cached English wiki page, when it's another character's
  def foreign_wiki_page(character)
    source = Source.fetch(character, :wiki_raw)
    page_id = source&.body.to_s[/\|\s*id\s*=\s*(\d{10})/, 1]
    source if page_id && page_id != character.granblue_id
  end
end
