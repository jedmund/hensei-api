# frozen_string_literal: true

class MigrateSeriesOnWeaponKey < ActiveRecord::Migration[8.0]
  def up
    WeaponKey.transaction do
      puts 'Starting weapon key series migration...'

      puts 'Updating Telumas (3 -> 27)...'
      WeaponKey.where('? = ANY(series)', 3).update_all('series = array_replace(series, 3, 27)')

      puts 'Updating Providence Telumas (34 -> 40)...'
      WeaponKey.where('? = ANY(series)', 34).update_all('series = array_replace(series, 34, 40)')

      puts 'Updating Gauph Keys (17 -> 13)...'
      WeaponKey.where('? = ANY(series)', 17).update_all('series = array_replace(series, 17, 13)')

      puts 'Updating Pendulums (2 -> 3)...'
      WeaponKey.where('? = ANY(series)', 2).update_all('series = array_replace(series, 2, 3)')

      puts 'Updating Chains (2 -> 3)...'
      WeaponKey.where('? = ANY(series)', 2).update_all('series = array_replace(series, 2, 3)')

      puts 'Updating Emblems (24 -> 19)...'
      WeaponKey.where('? = ANY(series)', 24).update_all('series = array_replace(series, 24, 19)')

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
