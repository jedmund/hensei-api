# frozen_string_literal: true

# Limited weapons outside Classic whose pools disagree with their wiki source:
# - Grand weapons the wiki lists as Legend Festival (gala,normal) sat in Flash.
# - Summer weapons carried Legend, no pool, or Holiday (via a wrong recruit).
# - Rodentius (2020 zodiac) carried Flash as well as Legend.
# Summer Night Peak recruits SR Arulumaya (Yukata), who is tagged Summer
# season and Yukata series like the other Yukata characters.
#
# Every entry names its item and exact current values, so a drifted row aborts
# the whole run instead of moving the wrong item.
class CorrectLimitedWeaponPools < ActiveRecord::Migration[8.0]
  LEGEND = [5].freeze
  SUMMER = [7].freeze
  SUMMER_SEASON = 3
  YUKATA_SERIES = 11
  YUKATA_SLUG = 'yukata'

  WEAPONS = [
    { granblue_id: '1040108200', name: 'Reunion', recruits: '3040101000', before: [4], after: LEGEND },
    { granblue_id: '1040917100', name: 'Sennen Goji', recruits: '3040580000', before: [4], after: LEGEND },
    { granblue_id: '1040511900', name: 'Rodentius', recruits: '3040252000', before: [4, 5], after: LEGEND },
    { granblue_id: '1040423400', name: 'Dardur', recruits: '3040537000', before: [5, 7], after: SUMMER },
    { granblue_id: '1040517000', name: 'Aertire', recruits: '3040538000', before: [5, 7], after: SUMMER },
    { granblue_id: '1040320300', name: 'Exhilarating Banana', recruits: nil, recruits_after: '3040665000',
      before: [], after: SUMMER },
    { granblue_id: '1040221400', name: 'Netherbloom Parasol', recruits: nil, recruits_after: '3040664000',
      before: [], after: SUMMER },
    { granblue_id: '1030606800', name: 'Summer Night Peak', recruits: '3040104000', recruits_after: '3030249000',
      before: [9], after: SUMMER }
  ].freeze

  ARULUMAYA = { granblue_id: '3030249000', name: 'Arulumaya', rarity: 2 }.freeze

  def up
    transaction do
      execute 'LOCK TABLE weapons, characters, character_series_memberships IN SHARE ROW EXCLUSIVE MODE'
      weapons = preview
      character = preview_character

      weapons.each do |entry|
        next if entry[:before] == entry[:after] && entry[:recruits_before] == entry[:recruits_after]

        execute <<~SQL.squish
          UPDATE weapons
          SET promotions = ARRAY[#{entry[:after].join(',')}]::integer[], recruits = #{connection.quote(entry[:recruits_after])}
          WHERE id = #{connection.quote(entry[:id])}
        SQL
      end

      tag_yukata(character)
    end
  end

  # Resolves every weapon before any mutation; usable from rails runner to
  # review exact before/after values.
  def preview
    WEAPONS.map do |change|
      rows = connection.select_all(
        "SELECT id, name_en, recruits, promotions FROM weapons WHERE granblue_id = #{connection.quote(change[:granblue_id])}"
      ).to_a
      raise "Expected exactly one Weapon #{change[:granblue_id]}; found #{rows.length}" unless rows.length == 1

      row = rows.first
      raise "Name mismatch for #{change[:granblue_id]}: #{row['name_en'].inspect}" unless row['name_en'] == change[:name]

      recruits_after = change.fetch(:recruits_after, change[:recruits])
      unless [change[:recruits], recruits_after].include?(row['recruits'])
        raise "Recruitment mismatch for #{change[:granblue_id]}: #{row['recruits'].inspect}"
      end

      before = ActiveRecord::Type.lookup(:integer, array: true, adapter: :postgresql).deserialize(row['promotions']) || []
      unless [change[:before], change[:after]].include?(before.sort)
        raise "Pool drift for #{change[:granblue_id]}: #{before.inspect}"
      end

      { id: row['id'], granblue_id: change[:granblue_id], name: row['name_en'], before: before.sort,
        after: change[:after], recruits_before: row['recruits'], recruits_after: recruits_after }
    end
  end

  def preview_character
    rows = connection.select_all(<<~SQL.squish).to_a
      SELECT id, name_en, rarity, season, series FROM characters
      WHERE granblue_id = #{connection.quote(ARULUMAYA[:granblue_id])}
    SQL
    raise "Expected exactly one Character #{ARULUMAYA[:granblue_id]}; found #{rows.length}" unless rows.length == 1

    row = rows.first
    unless row['name_en'] == ARULUMAYA[:name] && row['rarity'].to_i == ARULUMAYA[:rarity]
      raise "Character mismatch for #{ARULUMAYA[:granblue_id]}: #{row['name_en'].inspect}"
    end

    series_id = connection.select_value(
      "SELECT id FROM character_series WHERE slug = #{connection.quote(YUKATA_SLUG)}"
    )
    raise 'Missing yukata character series' unless series_id

    { id: row['id'], series_id: series_id }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore previous pool membership from a reviewed backup.'
  end

  private

  def tag_yukata(character)
    execute <<~SQL.squish
      UPDATE characters
      SET season = #{SUMMER_SEASON},
          series = CASE WHEN #{YUKATA_SERIES} = ANY(series) THEN series ELSE array_append(series, #{YUKATA_SERIES}) END
      WHERE id = #{connection.quote(character[:id])}
    SQL
    execute <<~SQL.squish
      INSERT INTO character_series_memberships (id, character_id, character_series_id, created_at, updated_at)
      SELECT gen_random_uuid(), #{connection.quote(character[:id])}, #{connection.quote(character[:series_id])}, NOW(), NOW()
      WHERE NOT EXISTS (
        SELECT 1 FROM character_series_memberships
        WHERE character_id = #{connection.quote(character[:id])}
          AND character_series_id = #{connection.quote(character[:series_id])}
      )
    SQL
  end
end
