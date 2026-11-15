# frozen_string_literal: true

# Sets the gbf-wiki.com page title (wiki_ja) for ten summons whose title was missing or
# wrong, so `granblue:download_jp_wiki model=summon` fetches their pages (GBF-57). Every
# title was checked against the wiki's summon index (召喚石概要/召喚石一覧) and fetched on
# 2026-11-14. Summer summons are titled "<name> (SSR)水着バージョン"; Medusa, Sandalphon and
# Levin Sisters had titles that led to the wrong page or none.
#
# Rerunnable: it only writes titles that differ.
class SetJpWikiTitlesForSummons < ActiveRecord::Migration[8.1]
  TITLES = {
    '2030051000' => '召喚石/シルフィードベル (SR)',
    '2040189000' => '召喚石/レヴィオンシスターズ (SSR)',
    '2040335000' => '召喚石/サテュロス (SSR)水着バージョン',
    '2040411000' => '召喚石/ベリアル (SSR)水着バージョン',
    '2040293000' => '召喚石/マキュラ・マリウス (SSR)水着バージョン',
    '2040403000' => '召喚石/マンドラゴラ (SSR)水着バージョン',
    '2040333000' => '召喚石/ユグドラシル (SSR)水着バージョン',
    '2040059000' => '召喚石/メドゥーサ (SSR)',
    '2040195000' => '召喚石/サンダルフォン (SSR)',
    '2040429000' => '召喚石/ベルゼバブ (SSR)水着バージョン'
  }.freeze

  def up
    changed = TITLES.sum do |granblue_id, title|
      Summon.where(granblue_id: granblue_id).where.not(wiki_ja: title).or(
        Summon.where(granblue_id: granblue_id, wiki_ja: nil)
      ).update_all(wiki_ja: title)
    end
    say "set the Japanese wiki title on #{changed} summons"
  end

  def down
    # Nothing to undo: the old titles led to no page or the wrong one.
  end
end
