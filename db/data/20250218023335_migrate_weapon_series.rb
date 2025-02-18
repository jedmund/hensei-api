# frozen_string_literal: true

class MigrateWeaponSeries < ActiveRecord::Migration[8.0]
  def up
    Weapon.transaction do
      puts 'Starting weapon series migration...'

      puts 'Updating Seraphic Weapons (0 -> 1)...'
      Weapon.find_by(series: 0).update!(new_series: 1)

      puts 'Updating Grand Weapons (1 -> 2)...'
      Weapon.find_by(series: 1).update!(new_series: 2)

      puts 'Updating Dark Opus Weapons (2 -> 3)...'
      Weapon.find_by(series: 2).update!(new_series: 3)

      puts 'Updating Revenant Weapons (4 -> 4)...'
      Weapon.find_by(series: 4).update!(new_series: 4)

      puts 'Updating Primal Weapons (6 -> 5)...'
      Weapon.find_by(series: 6).update!(new_series: 5)

      puts 'Updating Beast Weapons (5, 7 -> 6)...'
      Weapon.find_by(series: 5).update!(new_series: 6)
      Weapon.find_by(series: 7).update!(new_series: 6)

      puts 'Updating Regalia Weapons (8 -> 7)...'
      Weapon.find_by(series: 8).update!(new_series: 7)

      puts 'Updating Omega Weapons (9 -> 8)...'
      Weapon.find_by(series: 9).update!(new_series: 8)

      puts 'Updating Olden Primal Weapons (10 -> 9)...'
      Weapon.find_by(series: 10).update!(new_series: 9)

      puts 'Updating Hollowsky Weapons (12 -> 10)...'
      Weapon.find_by(series: 12).update!(new_series: 10)

      puts 'Updating Xeno Weapons (13 -> 11)...'
      Weapon.find_by(series: 13).update!(new_series: 11)

      puts 'Updating Rose Weapons (15 -> 12)...'
      Weapon.find_by(series: 15).update!(new_series: 12)

      puts 'Updating Ultima Weapons (17 -> 13)...'
      Weapon.find_by(series: 17).update!(new_series: 13)

      puts 'Updating Bahamut Weapons (16 -> 14)...'
      Weapon.find_by(series: 16).update!(new_series: 14)

      puts 'Updating Epic Weapons (18 -> 15)...'
      Weapon.find_by(series: 18).update!(new_series: 15)

      puts 'Updating Cosmos Weapons (20 -> 16)...'
      Weapon.find_by(series: 20).update!(new_series: 16)

      puts 'Updating Superlative Weapons (22 -> 17)...'
      Weapon.find_by(series: 22).update!(new_series: 17)

      puts 'Updating Vintage Weapons (23 -> 18)...'
      Weapon.find_by(series: 23).update!(new_series: 18)

      puts 'Updating Class Champion Weapons (24 -> 19)...'
      Weapon.find_by(series: 24).update!(new_series: 19)

      puts 'Updating Sephira Weapons (28 -> 23)...'
      Weapon.find_by(series: 28).update!(new_series: 23)

      puts 'Updating Astral Weapons (14 -> 26)...'
      Weapon.find_by(series: 14).update!(new_series: 26)

      puts 'Updating Draconic Weapons (3 -> 27)...'
      Weapon.find_by(series: 3).update!(new_series: 27)

      puts 'Updating Ancestral Weapons (21 -> 29)...'
      Weapon.find_by(series: 21).update!(new_series: 29)

      puts 'Updating New World Foundation (29 -> 30)...'
      Weapon.find_by(series: 29).update!(new_series: 30)

      puts 'Updating Ennead Weapons (19 -> 31)...'
      Weapon.find_by(series: 19).update!(new_series: 31)

      puts 'Updating Militis Weapons (11 -> 32)...'
      Weapon.find_by(series: 11).update!(new_series: 32)

      puts 'Updating Malice Weapons (26 -> 33)...'
      Weapon.find_by(series: 26).update!(new_series: 33)

      puts 'Updating Menace Weapons (26 -> 34)...'
      Weapon.find_by(series: 26).update!(new_series: 34)

      puts 'Updating Illustrious Weapons (31 -> 35)...'
      Weapon.find_by(series: 31).update!(new_series: 35)

      puts 'Updating Proven Weapons (25 -> 36)...'
      Weapon.find_by(series: 25).update!(new_series: 36)

      puts 'Updating Revans Weapons (30 -> 37)...'
      Weapon.find_by(series: 30).update!(new_series: 37)

      puts 'Updating World Weapons (32 -> 38)...'
      Weapon.find_by(series: 32).update!(new_series: 38)

      puts 'Updating Exo Weapons (33 -> 39)...'
      Weapon.find_by(series: 33).update!(new_series: 39)

      puts 'Updating Draconic Weapons Providence (34 -> 40)...'
      Weapon.find_by(series: 34).update!(new_series: 40)

      puts 'Updating Celestial Weapons (37 -> 41)...'
      Weapon.find_by(series: 37).update!(new_series: 41)

      puts 'Updating Omega Rebirth Weapons (38 -> 42)...'
      Weapon.find_by(series: 38).update!(new_series: 42)

      puts 'Updating Event Weapons (34 -> 98)...'
      Weapon.find_by(series: 34).update!(new_series: 98) # Event

      puts 'Updating Gacha Weapons (36 -> 99)...'
      Weapon.find_by(series: 36).update!(new_series: 99) # Gacha

      puts 'Migration completed successfully!'
    rescue StandardError => e
      puts "Error occurred during migration: #{e.message}"
      puts "Backtrace: #{e.backtrace}"
      raise e
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
