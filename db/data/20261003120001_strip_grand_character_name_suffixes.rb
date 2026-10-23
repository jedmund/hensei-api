# frozen_string_literal: true

# Grand characters carried a disambiguating " (Grand)" in name_en and
# "(リミテッドver)" in name_jp. The game shows them by their plain name and the
# web app tells variants apart with character tags, so the suffixes come off
# and shared names are expected. Each entry names the character's current
# names; a row whose names have drifted aborts the whole run.
class StripGrandCharacterNameSuffixes < ActiveRecord::Migration[8.0]
  EN_SUFFIX = /\s*\(Grand\)\z/
  JP_SUFFIX = /\s*[(（]リミテッドver[)）]\z/

  # [granblue_id, name_en, name_jp] as they read before this migration.
  # 3040101000 is also carried by a second Lecia row, so rows are matched on
  # their names as well as their id.
  CHARACTERS = [
    ['3040054000', 'Katalina (Grand)', 'カタリナ(リミテッドver)'],
    ['3040065000', 'Io (Grand)', 'イオ(リミテッドver)'],
    ['3040082000', 'Black Knight', '黒騎士(リミテッドver)'],
    ['3040092000', 'Zooey (Grand)', 'ゾーイ(リミテッドver)'],
    ['3040101000', 'Lecia (Grand)', 'リーシャ(リミテッドver)'],
    ['3040106000', 'Lucio', 'ルシオ(リミテッドver)'],
    ['3040111000', 'Orchid (Grand)', 'オーキス(リミテッドver)'],
    ['3040158000', 'Alexiel', 'ブローディア(リミテッドver)'],
    ['3040181000', 'Pholia', 'フォリア(リミテッドver)'],
    ['3040190000', 'Europa', 'エウロペ(リミテッドver)'],
    ['3040196000', 'Shiva', 'シヴァ(リミテッドver)'],
    ['3040209000', 'Ferry (Grand)', 'フェリ(リミテッドver)'],
    ['3040245000', 'Jeanne d\'Arc (Grand)', 'ジャンヌダルク(リミテッドver)'],
    ['3040251000', 'Helel ben Shalem', 'ヘレル・ベン・シャレム(リミテッドver)'],
    ['3040265000', 'Rei', 'レイ(リミテッドver)'],
    ['3040274000', 'Reinhardtzar (Grand)', 'ラインハルザ(リミテッドver)'],
    ['3040285000', 'Leona (Grand)', 'レオナ(リミテッドver)'],
    ['3040312000', 'Sandalphon', 'サンダルフォン(リミテッドver)'],
    ['3040357000', 'Lich', 'リッチ（リミテッドver）'],
    ['3040443000', 'Halluel and Malluel', 'ハールート・マールート(リミテッドver)'],
    ['3040467000', 'Cosmos', 'コスモス(リミテッドver)']
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE characters IN SHARE ROW EXCLUSIVE MODE'
      preview.each do |entry|
        next if entry[:before] == entry[:after]

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

  # Not reversible by name: the second Lecia row already reads "Lecia".
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
