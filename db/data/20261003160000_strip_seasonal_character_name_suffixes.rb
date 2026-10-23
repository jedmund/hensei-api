# frozen_string_literal: true

# Summer and Halloween characters carried their season in their names
# (" (Summer)", "（水着バージョン）", "(ハロウィンver)" and variants). The web app
# shows the season as a character tag, so the suffixes come off and shared
# names are expected. Every character here has its season set, so the tag
# still appears. Non-season suffixes (element, rarity, Event, Promo) stay.
#
# Each entry names the character's current names; a row whose names have
# drifted aborts the whole run.
class StripSeasonalCharacterNameSuffixes < ActiveRecord::Migration[8.0]
  EN_SUFFIX = /\s*\((?:Summer|Halloween)\)\z/
  JP_SUFFIX = /\s*[(（](?:水着バージョン|水着ver|ハロウィンver)[)）]\z/

  # [granblue_id, name_en, name_jp] as they read before this migration.
  CHARACTERS = [
    ['3030250000', 'Almeida (Summer)', 'アルメイダ（水着バージョン）'],
    ['3020021000', 'Anna (Summer)', 'アンナ'],
    ['3030199000', 'Ayer (Summer)', 'アイル（水着バージョン）'],
    ['3030152000', 'Camieux (Summer)', 'クムユ(水着ver)'],
    ['3030198000', 'Charlotta (Summer)', 'シャルロッテ（水着バージョン）'],
    ['3030202000', 'Chloe (Summer)', 'クロエ（水着バージョン）'],
    ['3040055000', 'Danua (Summer)', 'ダヌア(水着バージョン）'],
    ['3040014000', 'De La Fille (Summer)', 'レ・フィーエ（水着バージョン）'],
    ['3040129000', 'Diantha (Summer)', 'ディアンサ（水着バージョン）'],
    ['3030083000', 'Elmott (Summer)', 'エルモート（水着バージョン）'],
    ['3030085000', 'Eugen (Summer)', 'オイゲン（水着バージョン）'],
    ['3040226000', 'Europa (Summer)', 'エウロペ（水着バージョン）'],
    ['3030248000', 'Farrah (Summer)', 'ファラ（水着バージョン）'],
    ['3030310000', 'Ferry (Summer)', 'フェリ（水着バージョン）'],
    ['3030201000', 'Ghandagoza (Summer)', 'ガンダゴウザ（水着バージョン）'],
    ['3040179000', 'Grea (Summer)', 'グレア（水着バージョン）'],
    ['3040091000', 'Heles (Summer)', 'ヘルエス（水着バージョン）'],
    ['3030031000', 'Helnar (Summer)', 'ヘルナル（水着バージョン）'],
    ['3040177000', 'Ilsa (Summer)', 'イルザ（水着バージョン）'],
    ['3040015000', 'Io (Summer)', 'イオ（水着バージョン）'],
    ['3020060000', 'Ippatsu (Summer)', 'イッパツ'],
    ['3040126000', 'Izmir (Summer)', 'イシュミール（水着バージョン）'],
    ['3030149000', 'J.J. (Summer)', 'Ｊ・Ｊ（水着バージョン）'],
    ['3040154000', 'Jeanne d\'Arc (Summer)', 'ジャンヌダルク（水着バージョン）'],
    ['3030030000', 'Jessica (Summer)', 'ジェシカ(水着バージョン）'],
    ['3030178000', 'Jin (Summer)', 'ジン（水着バージョン）'],
    ['3030029000', 'Katalina (Summer)', 'カタリナ（水着バージョン）'],
    ['3040283000', 'Kolulu (Summer)', 'コルル（水着バージョン）'],
    ['3040127000', 'Korwa (Summer)', 'コルワ（水着バージョン）'],
    ['3030272000', 'Lancelot and Vane (Summer)', '白竜の双騎士 ランスロット＆ヴェイン（水着バージョン）'],
    ['3030087000', 'Lecia (Summer)', 'リーシャ（水着バージョン）'],
    ['3020041000', 'Lowain (Summer)', 'ローアイン'],
    ['3040286000', 'Lucio (Summer)', 'ルシオ（水着バージョン）'],
    ['3020061000', 'Lunalu (Summer)', 'ルナール'],
    ['3040292000', 'Mimlemel (Summer)', 'ミムルメモル（水着バージョン）'],
    ['3040178000', 'Naoise (Summer)', 'ノイシュ(水着バージョン)'],
    ['3040089000', 'Narmaya (Summer)', 'ナルメア（水着バージョン）'],
    ['3030246000', 'Olivia (Event)', 'オリヴィエ(水着ver)'],
    ['3040090000', 'Percival (Summer)', 'パーシヴァル（水着バージョン）'],
    ['3040176000', 'Rosetta (Summer)', 'ロゼッタ（水着バージョン）'],
    ['3030147000', 'Sara (Summer)', 'サラ（水着バージョン）'],
    ['3040291000', 'Silva (Summer)', 'シルヴァ（水着バージョン）'],
    ['3030091000', 'Suframare (Summer)', 'スフラマール（水着バージョン）'],
    ['3030084000', 'Tanya (Summer)', 'ターニャ（水着バージョン）'],
    ['3040266000', 'Teena (Summer)', 'ティナ（水着バージョン）'],
    ['3040053000', 'Vira (Summer)', 'ヴィーラ（水着バージョン）'],
    ['3020022000', 'Walder (Summer)', 'ウェルダー'],
    ['3040210000', 'Yuel (Summer)', 'ユエル（水着バージョン）'],
    ['3030042000', 'Ange (Halloween)', 'アンジェ(ハロウィンver)'],
    ['3040135000', 'Danua (Halloween)', 'ダヌア(ハロウィンver)'],
    ['3030254000', 'Feather (Halloween)', 'フェザー(ハロウィンver)'],
    ['3030101000', 'Ferry (Halloween)', 'フェリ(ハロウィンver)'],
    ['3040189000', 'Lady Grey (Halloween)', 'レディ・グレイ(ハロウィンver)'],
    ['3030220000', 'Mimlemel and Pun-Kin (Halloween)', 'ミムルメモル＆パンプキン(ハロウィンver)'],
    ['3040301000', 'Rosetta (Halloween)', 'ロゼッタ(ハロウィンver)'],
    ['3030321000', 'Wulf and Renie (Halloween)', 'ウーフとレニー(ハロウィンver)'],
    ['3030276000', 'Zaja (Halloween)', 'ザザ(ハロウィンver)']
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE characters IN SHARE ROW EXCLUSIVE MODE'
      preview.each do |entry|
        execute <<~SQL.squish
          UPDATE characters
          SET name_en = #{connection.quote(entry[:after][0])}, name_jp = #{connection.quote(entry[:after][1])}
          WHERE id = #{connection.quote(entry[:id])}
        SQL
      end
    end
  end

  # Resolves every character before any mutation; usable from rails runner to
  # review exact before/after names. A character already renamed by an earlier
  # run resolves as a no-op.
  def preview
    CHARACTERS.filter_map do |granblue_id, name_en, name_jp|
      after = [name_en.sub(EN_SUFFIX, ''), name_jp.sub(JP_SUFFIX, '')]
      rows = named(granblue_id, name_en, name_jp)
      raise "Expected at most one Character #{granblue_id} named #{name_en}; found #{rows.length}" if rows.length > 1
      if rows.empty?
        raise "Missing Character #{granblue_id} named #{name_en}" if named(granblue_id, *after).empty?

        next
      end

      { id: rows.first['id'], granblue_id: granblue_id, before: [name_en, name_jp], after: after }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore previous names from CHARACTERS or a reviewed backup.'
  end

  private

  def named(granblue_id, name_en, name_jp)
    connection.select_all(<<~SQL.squish).to_a
      SELECT id FROM characters
      WHERE granblue_id = #{connection.quote(granblue_id)}
        AND name_en = #{connection.quote(name_en)} AND name_jp = #{connection.quote(name_jp)}
    SQL
  end
end
