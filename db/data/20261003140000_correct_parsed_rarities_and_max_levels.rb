# frozen_string_literal: true

# The wiki import looked rarity up case-sensitively, but most pages write
# "sr"/"r", so the rarity came back empty and the max level fell through to
# the SSR value (100). Values below come from the gbf.wiki Cargo weapons table
# (rarity, evo_max): every weapon here caps at 3★ (R 50, SR 75) except the
# Touken Ranbu collab swords, SR weapons that reach Level 120 at 4★. Summon and
# character rows follow their wiki pages (SR summons cap at 75).
#
# Every entry names its item and exact current values, so a drifted row aborts
# the whole run instead of changing the wrong item.
class CorrectParsedRaritiesAndMaxLevels < ActiveRecord::Migration[8.0]
  # [granblue_id, name_en, rarity, max_level, rarity_after, max_level_after]
  WEAPONS = [
    ['1020102100', 'Wooden Dagger', 1, 100, 1, 50],
    ['1020102400', 'Cleaver', 1, 100, 1, 50],
    ['1020402100', 'Cursed Flame Candelabra', 1, 100, 1, 50],
    ['1020402200', 'Tree Wand', 1, 100, 1, 50],
    ['1020500100', 'Petronel', 1, 100, 1, 50],
    ['1020501200', 'Firecracker', 1, 100, 1, 50],
    ['1020601900', 'Cold Noodles', 1, 100, 1, 50],
    ['1020800100', 'Night Bell', 1, 100, 1, 50],
    ['1020800200', 'Night Air Bell', 1, 100, 1, 50],
    ['1030004400', 'Sword of Bahamut', 2, 100, 2, 75],
    ['1030005700', 'Delta Apex', 2, 100, 2, 75],
    ['1030007200', 'Summer Souteyrand', 2, 100, 2, 75],
    ['1030007300', 'Macuahuitl', 2, 100, 2, 75],
    ['1030007800', 'Festive Frying Pan', 2, 100, 2, 75],
    ['1030008700', 'Premium Sword', 2, 100, 2, 75],
    ['1030010500', 'Beak Slasher', 2, 100, 2, 75],
    ['1030103800', 'Dagger of Bahamut', 2, 100, 2, 75],
    ['1030109400', 'Nightfall\'s Wing', 2, 100, 2, 75],
    ['1030109500', 'Kahuan Pahoa', 2, 100, 2, 75],
    ['1030203700', 'Spear of Bahamut', 2, 100, 2, 75],
    ['1030207200', 'Knight\'s Beach Banner', 2, 100, 2, 75],
    ['1030302900', 'Axe of Bahamut', 2, 100, 2, 75],
    ['1030304300', 'Gold-Plated Fremel', 2, 100, 2, 75],
    ['1030304900', 'Horrible Voulge', 2, 100, 2, 75],
    ['1030306100', 'Miner\'s Lantern', 2, 100, 2, 75],
    ['1030403200', 'Staff of Bahamut', 2, 100, 2, 75],
    ['1030405200', 'Scarlet Oath', 2, 100, 2, 75],
    ['1030406700', 'Vocazione', 2, 100, 2, 75],
    ['1030406800', 'Achromatic Palette', 2, 100, 2, 75],
    ['1030502600', 'Pistol of Bahamut', 2, 100, 2, 75],
    ['1030504800', 'Winter Wonderbow', 2, 100, 2, 75],
    ['1030603700', 'Fist of Bahamut', 2, 100, 2, 75],
    ['1030605000', 'White Talons', 2, 100, 2, 75],
    ['1030605500', 'Tropical Punch', 2, 100, 2, 75],
    ['1030605600', 'Rope Knuckles', 2, 100, 2, 75],
    ['1030605700', 'Seaside Memory', 2, 100, 2, 75],
    ['1030605900', 'Heavy-Duty Pumpkins', 2, 100, 2, 75],
    ['1030606800', 'Summer Night Peak', 2, 100, 2, 75],
    ['1030608100', 'Phantom Gauntlet', 2, 100, 2, 75],
    ['1030608400', 'Cotton Candy', 2, 100, 2, 75],
    ['1030609900', 'Brennuglofi', 2, 100, 2, 75],
    ['1030702400', 'Bow of Bahamut', 2, 100, 2, 75],
    ['1030704900', 'Motherly Flower Wreath', 2, 69, 2, 75],
    ['1030802000', 'Harp of Bahamut', 2, 100, 2, 75],
    ['1030803500', 'Summer Beach Sphere', 2, 100, 2, 75],
    ['1030900500', 'Blade of Bahamut', 2, 100, 2, 75],
    ['1030902400', 'Honebami Toushirou', 2, 150, 2, 120],
    ['1030902500', 'Mutsunokami Yoshiyuki', 3, 120, 2, 120],
    ['1030902600', 'Izuminokami Kanesada', 3, 120, 2, 120],
    ['1030902700', 'Yamanbagiri Kunihiro', 3, 120, 2, 120],
    ['1030902900', 'Confection Cutter', 2, 100, 2, 75],
    ['1030903400', 'Liuyedao', 2, 100, 2, 75]
  ].freeze

  SUMMONS = [
    ['2030051000', 'Belle Sylphid', 2, 100, 2, 75]
  ].freeze

  # [granblue_id, name_en, rarity, rarity_after]
  CHARACTERS = [
    ['3030231000', 'Zeta', 1, 2]
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE weapons, summons, characters IN SHARE ROW EXCLUSIVE MODE'
      entries = preview
      entries.each do |entry|
        next if entry[:before] == entry[:after]

        assignments = entry[:after].map { |column, value| "#{column} = #{Integer(value)}" }.join(', ')
        execute "UPDATE #{entry[:table]} SET #{assignments} WHERE id = #{connection.quote(entry[:id])}"
      end
    end
  end

  # Resolves every item before any mutation; usable from rails runner to
  # review exact before/after values.
  def preview
    leveled = WEAPONS.map { |row| ['weapons', row] } + SUMMONS.map { |row| ['summons', row] }
    leveled.map do |table, (granblue_id, name, rarity, level, rarity_after, level_after)|
      resolve(table, granblue_id, name, { 'rarity' => rarity, 'max_level' => level },
              { 'rarity' => rarity_after, 'max_level' => level_after })
    end + CHARACTERS.map do |granblue_id, name, rarity, rarity_after|
      resolve('characters', granblue_id, name, { 'rarity' => rarity }, { 'rarity' => rarity_after })
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore previous values from a reviewed backup.'
  end

  private

  def resolve(table, granblue_id, name, before, after)
    rows = connection.select_all(
      "SELECT id, name_en, #{before.keys.join(', ')} FROM #{table} WHERE granblue_id = #{connection.quote(granblue_id)}"
    ).to_a
    raise "Expected exactly one #{table} row #{granblue_id}; found #{rows.length}" unless rows.length == 1

    row = rows.first
    raise "Name mismatch for #{granblue_id}: #{row['name_en'].inspect}" unless row['name_en'] == name

    current = before.keys.index_with { |column| row[column].to_i }
    raise "Value drift for #{granblue_id}: #{current.inspect}" unless [before, after].include?(current)

    { table: table, id: row['id'], granblue_id: granblue_id, name: name, before: current, after: after }
  end
end
