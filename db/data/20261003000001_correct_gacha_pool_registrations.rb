# frozen_string_literal: true

# Reviewed pool corrections for character weapons and summons. Each weapon
# entry names the character it must recruit and each summon entry names the
# summon, so a drifted row aborts the whole run instead of moving the wrong item.
class CorrectGachaPoolRegistrations < ActiveRecord::Migration[8.0]
  PREMIUM = 1
  CLASSIC = 2
  CLASSIC_II = 3
  FLASH = 4
  LEGEND = 5
  SUMMER = 7
  ORDINARY = [1, 4, 5, 6, 7, 8, 9].freeze
  TABLES = { 'Weapon' => 'weapons', 'Summon' => 'summons' }.freeze

  # Summons the wiki lists as Classic II only.
  CLASSIC_II_SUMMONS = {
    '2040263000' => 'Tsukuyomi',
    '2040253000' => 'Adramelech',
    '2040249000' => 'Snow White',
    '2040233000' => 'Ankusha',
    '2040229000' => 'Zaoshen',
    '2040221000' => 'Garula, Shining Hawk',
    '2040216000' => 'Aphrodite',
    '2040212000' => 'Nacht',
    '2040105000' => 'Rose Queen',
    '2040180000' => 'Typhon',
    '2040177000' => 'Setekh',
    '2040173000' => 'Tezcatlipoca',
    '2040171000' => 'Sethlans'
  }.freeze

  CHANGES = [
    # Octavia joins the Flash Gala pool.
    { type: 'Weapon', granblue_id: '1040918400', recruits: '3040644000', add: [FLASH] },
    # Payila joins the Legend Gala pool.
    { type: 'Weapon', granblue_id: '1040119000', recruits: '3040502000', add: [LEGEND] },
    # Indala was last year's year spirit and leaves every pool.
    { type: 'Weapon', granblue_id: '1040028100', recruits: '3040569000', clear: true },
    # Swan recruits Vane (Grand), not Vane (SSR), and stays in the Legend Gala pool.
    { type: 'Weapon', granblue_id: '1040318400', recruits: '3040117000', recruits_after: '3040551000', add: [LEGEND] },
    *CLASSIC_II_SUMMONS.map do |granblue_id, name|
      { type: 'Summon', granblue_id: granblue_id, name: name, remove: ORDINARY, add: [CLASSIC_II] }
    end,
    # Morrigna and Prometheus are Classic, not Classic II.
    { type: 'Summon', granblue_id: '2040122000', name: 'Morrigna', remove: [CLASSIC_II], add: [CLASSIC] },
    { type: 'Summon', granblue_id: '2040125000', name: 'Prometheus', remove: [CLASSIC_II], add: [CLASSIC] },
    # Ms. Tart Man is a summer-limited summon.
    { type: 'Summon', granblue_id: '2040461000', name: 'Ms. Tart Man', add: [SUMMER] }
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE weapons, summons IN SHARE ROW EXCLUSIVE MODE'
      preview.each do |entry|
        next if entry[:before] == entry[:after] && entry[:recruits_before] == entry[:recruits_after]

        assignments = ["promotions = ARRAY[#{entry[:after].join(',')}]::integer[]"]
        assignments << "recruits = #{connection.quote(entry[:recruits_after])}" if entry[:table] == 'weapons'
        execute "UPDATE #{entry[:table]} SET #{assignments.join(', ')} WHERE id = #{connection.quote(entry[:id])}"
      end
    end
  end

  # Resolves every item before any mutation; usable from rails runner to
  # review exact before/after values.
  def preview
    CHANGES.map do |change|
      table = TABLES.fetch(change[:type])
      columns = table == 'weapons' ? 'id, name_en, recruits, promotions' : 'id, name_en, promotions'
      rows = connection.select_all(
        "SELECT #{columns} FROM #{table} WHERE granblue_id = #{connection.quote(change[:granblue_id])}"
      ).to_a
      raise "Expected exactly one #{change[:type]} #{change[:granblue_id]}; found #{rows.length}" unless rows.length == 1

      row = rows.first
      recruits_after = change.fetch(:recruits_after, change[:recruits])
      if table == 'weapons' && ![change[:recruits], recruits_after].include?(row['recruits'])
        raise "Recruitment mismatch for #{change[:granblue_id]}: #{row['recruits'].inspect}"
      end
      if change[:name] && row['name_en'] != change[:name]
        raise "Name mismatch for #{change[:granblue_id]}: #{row['name_en'].inspect}"
      end

      before = ActiveRecord::Type.lookup(:integer, array: true, adapter: :postgresql).deserialize(row['promotions']) || []
      after = change[:clear] ? [] : ((before - change.fetch(:remove, [])) + change.fetch(:add, [])).uniq.sort

      { table: table, id: row['id'], granblue_id: change[:granblue_id], name: row['name_en'], before: before,
        after: after, recruits_before: row['recruits'], recruits_after: recruits_after }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore previous pool membership from a reviewed backup.'
  end
end
