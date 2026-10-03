# frozen_string_literal: true

# Ordinary Premium items appear in every banner but Classic: Flash, Legend,
# each season (Formal included) and Collab draws all carry the Premium pool.
# The catalogue stored them three ways ({1}, {1,4-9} and {1,4-11}), so every
# item in Premium is brought up to the full set, keeping its Classic pools.
#
# Reviewed corrections alongside:
# - collab draw summons (premium,collab, Tensura onward) join the Collab pool
# - Gorilla and Demonbream are Classic III only (wiki obtain=classic3)
# - Cords of Heaven Lillah and Windflash are Classic only (wiki obtain=classic)
# - Keraunos is a class champion weapon and is in no pool
#
# Every reviewed entry names its item and exact current pools, so a drifted
# row aborts the whole run instead of moving the wrong item.
class NormalizePremiumAndCollabPools < ActiveRecord::Migration[8.0]
  PREMIUM = 1
  ORDINARY = [1, 4, 5, 6, 7, 8, 9, 10, 11].freeze
  TABLES = { 'Weapon' => 'weapons', 'Summon' => 'summons' }.freeze

  CHANGES = [
    { type: 'Summon', granblue_id: '2040439000', name: 'Nobunaga, Feitan, Machi, and Uvogin', before: [], after: [10] },
    { type: 'Summon', granblue_id: '2040444000', name: 'Trigger of Awakening: Shinji and Rei', before: [], after: [10] },
    { type: 'Summon', granblue_id: '2040460000', name: 'Kisuke Urahara', before: [], after: [10] },
    { type: 'Summon', granblue_id: '2040285000', name: 'Gorilla', before: [1, 4, 5, 6, 7, 8, 9, 12], after: [12] },
    { type: 'Summon', granblue_id: '2040326000', name: 'Demonbream', before: [1, 4, 5, 6, 7, 8, 9, 12], after: [12] },
    { type: 'Weapon', granblue_id: '1040802400', name: 'Cords of Heaven Lillah', before: [1, 4, 5, 6, 7, 8, 9],
      after: [2] },
    { type: 'Weapon', granblue_id: '1040300600', name: 'Windflash', before: [1, 4, 5, 6, 7, 8, 9], after: [2] },
    { type: 'Weapon', granblue_id: '1040402900', name: 'Keraunos', before: [7], after: [] }
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE weapons, summons IN SHARE ROW EXCLUSIVE MODE'
      reviewed = preview
      reviewed.each do |entry|
        next if entry[:before] == entry[:after]

        execute "UPDATE #{entry[:table]} SET promotions = #{array(entry[:after])} WHERE id = #{connection.quote(entry[:id])}"
      end

      ids = reviewed.map { |entry| connection.quote(entry[:id]) }.join(', ')
      TABLES.each_value do |table|
        updated = connection.update(<<~SQL.squish)
          UPDATE #{table}
          SET promotions = ARRAY(SELECT DISTINCT unnest(promotions || #{array(ORDINARY)}) ORDER BY 1)
          WHERE #{PREMIUM} = ANY(promotions) AND NOT promotions @> #{array(ORDINARY)} AND id NOT IN (#{ids})
        SQL
        say "Brought #{updated} #{table} up to every non-Classic pool"
      end
    end
  end

  # Resolves every reviewed item before any mutation; usable from rails runner
  # to review exact before/after values.
  def preview
    CHANGES.map do |change|
      table = TABLES.fetch(change[:type])
      rows = connection.select_all(
        "SELECT id, name_en, promotions FROM #{table} WHERE granblue_id = #{connection.quote(change[:granblue_id])}"
      ).to_a
      raise "Expected exactly one #{change[:type]} #{change[:granblue_id]}; found #{rows.length}" unless rows.length == 1

      row = rows.first
      raise "Name mismatch for #{change[:granblue_id]}: #{row['name_en'].inspect}" unless row['name_en'] == change[:name]

      before = ActiveRecord::Type.lookup(:integer, array: true, adapter: :postgresql).deserialize(row['promotions']) || []
      unless [change[:before], change[:after]].include?(before.sort)
        raise "Pool drift for #{change[:granblue_id]}: #{before.inspect}"
      end

      { table: table, id: row['id'], granblue_id: change[:granblue_id], name: row['name_en'], before: before.sort,
        after: change[:after] }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore previous pool membership from a reviewed backup.'
  end

  private

  def array(values)
    "ARRAY[#{values.map { |value| Integer(value) }.join(',')}]::integer[]"
  end
end
