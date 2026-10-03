# frozen_string_literal: true

# Classic pools only hold Premium items from their release window
# (https://gbf.wiki/Draw#Classic). These weapons were filed by release date
# alone, which put Grand, Zodiac and seasonal weapons into Classic II (and
# Water Balloons into Premium and Classic). Each is restored to the pool its
# wiki `obtain` field names, matching every other weapon with that source:
# gala,flash -> Flash Gala, zodiac -> Legend Festival, a season -> that season.
#
# Every entry names its weapon, recruited character and exact current pools,
# so a drifted row aborts the whole run instead of moving the wrong item.
class RestoreLimitedWeaponPools < ActiveRecord::Migration[8.0]
  CLASSIC_II = [3].freeze
  FLASH = [4].freeze
  LEGEND = [5].freeze
  VALENTINE = [6].freeze
  SUMMER = [7].freeze
  HALLOWEEN = [8].freeze
  HOLIDAY = [9].freeze

  CHANGES = [
    # Grand weapons (gala,flash)
    { granblue_id: '1040008700', name: 'Blutgang', recruits: '3040082000', before: CLASSIC_II, after: FLASH },
    { granblue_id: '1040108700', name: 'Parazonium', recruits: '3040111000', before: CLASSIC_II, after: FLASH },
    { granblue_id: '1040207000', name: 'Eden', recruits: '3040106000', before: CLASSIC_II, after: FLASH },
    { granblue_id: '1040309000', name: 'Certificus', recruits: '3040141000', before: CLASSIC_II, after: FLASH },
    { granblue_id: '1040410000', name: 'Blue Sphere', recruits: '3040119000', before: CLASSIC_II, after: FLASH },
    { granblue_id: '1040605900', name: 'Cute Ribbon', recruits: '3040092000', before: CLASSIC_II, after: FLASH },
    { granblue_id: '1040906400', name: 'Ixaba', recruits: '3040115000', before: CLASSIC_II, after: FLASH },
    # Zodiac weapons
    { granblue_id: '1040609700', name: 'Canisius', recruits: '3040147000', before: CLASSIC_II, after: LEGEND },
    { granblue_id: '1040705400', name: 'Gallinarius', recruits: '3040107000', before: CLASSIC_II, after: LEGEND },
    # Summer
    { granblue_id: '1040009000', name: 'Antwerp', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040012500', name: 'Frostbite', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040108300', name: 'Delta Quartz', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040206600', name: 'Crystal Luin', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040608800', name: 'Tlepilli', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040806200', name: 'Bell of Happy Endings', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040905700', name: 'Raikiri', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1040908100', name: 'Sinensis', before: CLASSIC_II, after: SUMMER },
    { granblue_id: '1030604900', name: 'Water Balloons', before: [1, 2, 4, 5, 6, 7, 8, 9], after: SUMMER },
    # Halloween
    { granblue_id: '1040411500', name: 'Snack Pole', before: CLASSIC_II, after: HALLOWEEN },
    { granblue_id: '1040506300', name: 'Nightmare Mobilizer', before: CLASSIC_II, after: HALLOWEEN },
    # Holiday
    { granblue_id: '1040409100', name: 'Stardust Holly Rod', before: CLASSIC_II, after: HOLIDAY },
    { granblue_id: '1040508700', name: 'Jolly Starcracker', before: CLASSIC_II, after: HOLIDAY },
    # Valentine
    { granblue_id: '1040414000', name: 'Medusiana Staff', before: CLASSIC_II, after: VALENTINE }
  ].freeze

  def up
    transaction do
      execute 'LOCK TABLE weapons IN SHARE ROW EXCLUSIVE MODE'
      preview.each do |entry|
        next if entry[:before] == entry[:after]

        execute "UPDATE weapons SET promotions = ARRAY[#{entry[:after].join(',')}]::integer[] WHERE id = #{connection.quote(entry[:id])}"
      end
    end
  end

  # Resolves every weapon before any mutation; usable from rails runner to
  # review exact before/after values.
  def preview
    CHANGES.map do |change|
      rows = connection.select_all(
        "SELECT id, name_en, recruits, promotions FROM weapons WHERE granblue_id = #{connection.quote(change[:granblue_id])}"
      ).to_a
      raise "Expected exactly one Weapon #{change[:granblue_id]}; found #{rows.length}" unless rows.length == 1

      row = rows.first
      raise "Name mismatch for #{change[:granblue_id]}: #{row['name_en'].inspect}" unless row['name_en'] == change[:name]
      if change[:recruits] && row['recruits'] != change[:recruits]
        raise "Recruitment mismatch for #{change[:granblue_id]}: #{row['recruits'].inspect}"
      end

      before = ActiveRecord::Type.lookup(:integer, array: true, adapter: :postgresql).deserialize(row['promotions']) || []
      unless [change[:before], change[:after]].include?(before.sort)
        raise "Pool drift for #{change[:granblue_id]}: #{before.inspect}"
      end

      { id: row['id'], granblue_id: change[:granblue_id], name: row['name_en'], before: before.sort, after: change[:after] }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore previous pool membership from a reviewed backup.'
  end
end
