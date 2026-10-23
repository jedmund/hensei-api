# frozen_string_literal: true

# Event, Promo and rarity variants carried that in their names (" (Event)",
# " (SR)", "(イベントver)", "(ガチャver)" and so on). Characters are always shown
# with their art, and the web app shows Event and Promo as character tags, so
# the suffixes come off and shared names are expected. Event and Promo
# characters join those series first so their tag appears. Element suffixes
# stay for now.
#
# Each entry names the character's current names; a row whose names have
# drifted aborts the whole run.
class StripEventPromoRarityNameSuffixes < ActiveRecord::Migration[8.0]
  EN_SUFFIX = /\s*\((?:Event|Promo|SR|SSR|R)\)\z/
  JP_SUFFIX = /\s*[(（](?:イベントver|イベントバージョン|ガチャver|ガチャSRver|SR|SSR|R)[)）]\z/
  # English suffix => [character_series slug, legacy CHARACTER_SERIES value]
  SERIES = { 'Event' => ['event', 16], 'Promo' => ['promo', 4] }.freeze

  # [granblue_id, name_en, name_jp] as they read before this migration.
  CHARACTERS = [
    ['3020019000', 'Stan (Event)', 'スタン'],
    ['3020052000', 'Lamretta (R)', 'ラムレッダ(R)'],
    ['3030000000', 'Naoise (Promo)', 'ノイシュ'],
    ['3030001000', 'Therese (Event)', 'テレーズ'],
    ['3030011000', 'Abby (Promo)', 'アビー'],
    ['3030015000', 'Aliza (Event)', 'アリーザ'],
    ['3030016000', 'Jessica (Event)', 'ジェシカ'],
    ['3030021000', 'Sara (Event)', 'サラ'],
    ['3030022000', 'Jin (Event)', 'ジン'],
    ['3030026000', 'Selfira (Event)', 'セレフィラ'],
    ['3030028000', 'Sig (Event)', 'シグ'],
    ['3030032000', 'Ferry', 'フェリ(SR)'],
    ['3030035000', 'Feena (Event)', 'フィーナ'],
    ['3030037000', 'Farrah (SR)', 'ファラ'],
    ['3030038000', 'Juri (Event)', 'ユーリ'],
    ['3030044000', 'Aster (Event)', 'アステール'],
    ['3030047000', 'Vane (Event)', 'ヴェイン'],
    ['3030049000', 'Rosamia (SR)', 'ロザミア(SR)'],
    ['3030050000', 'Johann (Event)', 'ヨハン'],
    ['3030056000', 'Volenna (Event)', 'ボレミア'],
    ['3030060000', 'Zehek (Event)', 'ゼヘク(イベントver)'],
    ['3030063000', 'Sarya (Event)', 'サーヤ'],
    ['3030065000', 'Amira (SR)', 'アーミラ(SR)'],
    ['3030066000', 'Hazen (SR)', 'ヘイゼン'],
    ['3030067000', 'Syr (Event)', 'スィール'],
    ['3030068000', 'Mary (SR)', 'マリー'],
    ['3030073000', 'Pengy (Event)', 'ペンギー'],
    ['3030077000', 'Romeo (Event)', 'ロミオ(SR)'],
    ['3030078000', 'Feather (SR)', 'フェザー'],
    ['3030079000', 'Robomi (Event)', 'ロボミ'],
    ['3030092000', 'Will (SR)', 'ウィル'],
    ['3030094000', 'Galadar (SR)', 'ガラドア'],
    ['3030095000', 'Anna (SR)', 'アンナ'],
    ['3030096000', 'Naoise (Event)', 'ノイシュ(火属性ver)'],
    ['3030102000', 'Jasmine (SR)', 'ジャスミン'],
    ['3030103000', 'Farrah (Event)', 'ファラ(風属性ver)'],
    ['3030106000', 'Sig', 'シグ(ガチャver)'],
    ['3030107000', 'Vane', 'ヴェイン(ガチャver)'],
    ['3030108000', 'Lancelot (SR)', 'ランスロット(SR)'],
    ['3030112000', 'Skull (Event)', 'スカル'],
    ['3030116000', 'Daetta (SR)', 'ダエッタ'],
    ['3030117000', 'Soriz (Event)', 'ソリッズ(光属性ver)'],
    ['3030119000', 'Ryan (SR)', 'ライアン'],
    ['3030123000', 'Lowain (Event)', 'ローアイン'],
    ['3030128000', 'Eso (SR)', 'エシオ'],
    ['3030140000', 'Johann', 'ヨハン(ガチャver)'],
    ['3030141000', 'Nicholas (Event)', 'シロウ'],
    ['3030150000', 'Diantha (Promo)', 'ディアンサ'],
    ['3030153000', 'Pengy', 'ペンギー(ガチャSRver)'],
    ['3030154000', 'Barawa (Event)', 'バロワ'],
    ['3030156000', 'Dante (SR)', 'ダーント'],
    ['3030157000', 'Paris (Event)', 'パリス(イベントver)'],
    ['3030165000', 'Lily (Event)', 'リリィ(SR)'],
    ['3030167000', 'Tanya (SR)', 'ターニャ(SR)'],
    ['3030168000', 'Percival (Event)', 'パーシヴァル(SR)'],
    ['3030175000', 'Herja (SR)', 'ヘリヤ(SR)'],
    ['3030177000', 'Albert (Event)', 'アルベール(SR)'],
    ['3030183000', 'Vermeil (SR)', 'ヴェリトール'],
    ['3030187000', 'Sutera (Event)', 'スーテラ(イベントver)'],
    ['3030188000', 'Deliford (SR)', 'デリフォード'],
    ['3030189000', 'Cagliostro (Event)', 'カリオストロ(イベントバージョン)'],
    ['3030192000', 'Charlotta (Event)', 'シャルロッテ(イベントバージョン)'],
    ['3030195000', 'Jeanne d\'Arc (SR)', 'ジャンヌダルク(SR)'],
    ['3030197000', 'Walder (Event)', 'ウェルダー(イベントver)'],
    ['3030200000', 'Carren (Event)', 'カレン(イベントver)'],
    ['3030204000', 'Grea (Event)', 'グレア(SR)'],
    ['3030209000', 'Sarya', 'サーヤ(ガチャver)'],
    ['3030210000', 'Ezecrain (Event)', 'エゼクレイン(イベントver)'],
    ['3030221000', 'Vania (SR)', 'ヴァンピィ(SR)'],
    ['3030222000', 'Karteira (SR)', 'カルテイラ'],
    ['3030223000', 'Yuel (Event)', 'ユエル(イベントver)'],
    ['3030225000', 'Sophia (SR)', 'ソフィア(SR)'],
    ['3030226000', 'Arthur (Event)', 'アーサー'],
    ['3030230000', 'Karva (SR)', 'カルバ'],
    ['3030232000', 'Ippatsu (SR)', 'イッパツ(SR)'],
    ['3030233000', 'Zooey (Event)', 'ゾーイ(イベントver)'],
    ['3030234000', 'Randall (SR)', 'ランドル(SR)'],
    ['3030237000', 'Nezahualpilli (SR)', 'ネツァワルピリ(SR)'],
    ['3030239000', 'Barawa (SR)', 'バロワ(ガチャver)'],
    ['3030243000', 'Vanzza (SR)', 'ヴァンツァ(SR)'],
    ['3030246000', 'Olivia (Event)', 'オリヴィエ'],
    ['3030251000', 'Cailana (SR)', 'カイラナ(SR)'],
    ['3030256000', 'Rosine (SR)', 'ロジーヌ'],
    ['3030257000', 'Razia (SR)', 'ラスティナ(SR)'],
    ['3030258000', 'Sevilbarra (Event)', 'サビルバラ(イベントver)'],
    ['3030264000', 'Catherine (SR)', 'キャサリン(SR)'],
    ['3030266000', 'Korwa (SR)', 'コルワ(SR)'],
    ['3030267000', 'Richard (SR)', 'リチャード(SR)'],
    ['3030270000', 'Philosophia (SR)', 'フィラソピラ'],
    ['3030275000', 'La Coiffe (SR)', 'コワフュール'],
    ['3030277000', 'You (Event)', 'ヨウ'],
    ['3030278000', 'Krugne (SR)', 'クルーニ'],
    ['3030290000', 'Meg (Event)', 'メグ'],
    ['3030320000', 'Joel (SR)', 'ジョエル'],
    ['3040023000', 'Lancelot', 'ランスロット(SSR)'],
    ['3040041000', 'Sara', 'サラ(SSR)'],
    ['3040043000', 'Vira (SSR)', 'ヴィーラ(SSR)'],
    ['3040051000', 'Amira', 'アーミラ(SSR)'],
    ['3040061000', 'Feena', 'フィーナ(SSR)'],
    ['3040078000', 'Zooey (Promo)', 'ゾーイ'],
    ['3040083000', 'Aliza', 'アリーザ(SSR)'],
    ['3040117000', 'Vane (SSR)', 'ヴェイン(SSR)'],
    ['3040123000', 'Medusa (Promo)', 'メドゥーサ'],
    ['3040149000', 'Therese (SSR)', 'テレーズ(SSR)'],
    ['3040150000', 'Zooey', 'ゾーイ(ガチャver)'],
    ['3040155000', 'Robomi', 'ロボミ(SSR)'],
    ['3040156000', 'Nicholas', 'シロウ(SSR)'],
    ['3040159000', 'Cucouroux (SSR)', 'ククル(SSR)'],
    ['3040170000', 'Soriz (SSR)', 'ソリッズ(SSR)'],
    ['3040175000', 'Selfira', 'セレフィラ(SSR)'],
    ['3040203000', 'Tanya (SSR)', 'ターニャ(SSR)'],
    ['3040214000', 'Medusa', 'メドゥーサ(ガチャver)'],
    ['3040243000', 'Vira (Promo)', 'ヴィーラ(火属性ver)'],
    ['3040256000', 'Danua (SSR)', 'ダヌア(光属性ver)'],
    ['3040257000', 'Jin', 'ジン(SSR)'],
    ['3040271000', 'Herja (SSR)', 'ヘリヤ(SSR)'],
    ['3040278000', 'Predator (SSR)', 'プレデター(SSR)'],
    ['3040282000', 'Pengy (SSR)', 'ペンギー(SSR)'],
    ['3040284000', 'Abby', 'アビー(SSR)'],
    ['3040303000', 'Sutera (SSR)', 'スーテラ(SSR)'],
    ['3040304000', 'Feather (SSR)', 'フェザー(SSR)'],
    ['3040393000', 'You', 'ヨウ(SSR)']
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE characters, character_series_memberships IN SHARE ROW EXCLUSIVE MODE'
      series_ids = SERIES.values.to_h do |slug, _|
        id = connection.select_value("SELECT id FROM character_series WHERE slug = #{connection.quote(slug)}")
        raise "Missing #{slug} character series" unless id

        [slug, id]
      end

      preview.each do |entry|
        tag(entry[:id], series_ids.fetch(entry[:series][0]), entry[:series][1]) if entry[:series]
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

      { id: rows.first['id'], granblue_id: granblue_id, before: [name_en, name_jp], after: after,
        series: SERIES[name_en[EN_SUFFIX]&.strip&.delete('()')] }
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

  def tag(character_id, series_id, legacy_series)
    execute <<~SQL.squish
      UPDATE characters
      SET series = CASE WHEN #{legacy_series} = ANY(series) THEN series ELSE array_append(series, #{legacy_series}) END
      WHERE id = #{connection.quote(character_id)}
    SQL
    execute <<~SQL.squish
      INSERT INTO character_series_memberships (id, character_id, character_series_id, created_at, updated_at)
      SELECT gen_random_uuid(), #{connection.quote(character_id)}, #{connection.quote(series_id)}, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM character_series_memberships
        WHERE character_id = #{connection.quote(character_id)} AND character_series_id = #{connection.quote(series_id)}
      )
    SQL
  end
end
