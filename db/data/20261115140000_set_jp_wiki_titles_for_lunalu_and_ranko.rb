# frozen_string_literal: true

# Lunalu (2040286000) and Ranko Kanzaki (2040057000) are SSR summons, but their gbf-wiki.com
# title (wiki_ja) carried the rarity of the same-named character, so the stored Japanese page
# had no aura (GBF-57). These are the titles in the wiki's summon index
# (召喚石概要/召喚石一覧). Rerunnable: it only writes titles that differ.
class SetJpWikiTitlesForLunaluAndRanko < ActiveRecord::Migration[8.1]
  TITLES = {
    '2040286000' => '召喚石/ルナール (SSR)',
    '2040057000' => '召喚石/［覚醒魔王］神崎蘭子 (SSR)'
  }.freeze

  def up
    changed = TITLES.sum do |granblue_id, title|
      scope = Summon.where(granblue_id: granblue_id)
      scope.where.not(wiki_ja: title).or(scope.where(wiki_ja: nil)).update_all(wiki_ja: title)
    end
    say "set the Japanese wiki title on #{changed} summons"
  end

  def down
    # Nothing to undo: the old titles led to pages without the summon's aura.
  end
end
