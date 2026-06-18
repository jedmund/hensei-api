# frozen_string_literal: true

# Dual character+summon entities (archangels, Six Dragons, primal beasts, etc.) live at
# "Name (Summon)" on gbf.wiki, but our wiki_en pointed at the bare name (the character
# page) — so summon-aura fetches returned the character template (no aura fields) and
# these summons resolved to no aura data. Point wiki_en at the summon page; a subsequent
# `granblue:fetch_wiki_data type=Summon force=true` + `granblue:extract_summon_aura_data`
# then picks up their auras. (This lifted aura coverage of equipped summons 81% -> 100%.)
class FixDualEntitySummonWikiEn < ActiveRecord::Migration[8.0]
  WIKI_EN = {
    "2040021000" => "Athena (Summon)",
    "2040013000" => "Baal (Summon)",
    "2040032000" => "Cerberus (Summon)",
    "2040225000" => "Europa (Summon)",
    "2040406000" => "Ewiyar (Summon)",
    "2040418000" => "Fediel (Summon)",
    "2040281000" => "Freyr (Summon)",
    "2040311000" => "Gabriel (Summon)",
    "2040401000" => "Galleon (Summon)",
    "2040261000" => "Grimnir (Summon)",
    "2040275000" => "Halluel and Malluel (Summon)",
    "2040416000" => "Hekate (Summon)",
    "2040114000" => "Kaguya (Summon)",
    "2040189000" => "Levin Sisters (Summon)",
    "2040012000" => "Lich (Summon)",
    "2040409000" => "Lu Woh (Summon)",
    "2040286000" => "Lunalu (Summon)",
    "2040002000" => "Macula Marius (Summon)",
    "2040064000" => "Magus (Summon)",
    "2040059000" => "Medusa (Summon)",
    "2040330000" => "Metatron (Summon)",
    "2040306000" => "Michael (Summon)",
    "2040122000" => "Morrigna (Summon)",
    "2040042000" => "Nezha (Summon)",
    "2040424000" => "Noire (Summon)",
    "2040433000" => "Orologia (Summon)",
    "2040037000" => "Poseidon (Summon)",
    "2040057000" => "Ranko Kanzaki (Summon)",
    "2040202000" => "Raphael (Summon)",
    "2040195000" => "Sandalphon (Summon)",
    "2040327000" => "Sariel (Summon)",
    "2040053000" => "Satyr (Summon)",
    "2040185000" => "Shiva (Summon)",
    "2040048000" => "Sylph (Summon)",
    "2040263000" => "Tsukuyomi (Summon)",
    "2040203000" => "Uriel (Summon)",
    "2040413000" => "Wamdus (Summon)",
    "2040398000" => "Wilnas (Summon)",
    "2040417000" => "Yatima (Summon)"
  }.freeze

  def up
    WIKI_EN.each do |granblue_id, wiki_en|
      Summon.where(granblue_id: granblue_id).update_all(wiki_en: wiki_en)
    end
  end

  def down
    # No-op: the prior values were the bare character-page names (not worth restoring).
  end
end
