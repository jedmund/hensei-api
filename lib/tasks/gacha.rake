# frozen_string_literal: true

namespace :gacha do
  desc 'Migrate gacha table data to promotions arrays on weapons and summons'
  task migrate_promotions: :environment do
    test_mode = ENV['TEST'] == 'true'

    # Mapping from gacha table boolean columns to PROMOTIONS enum values
    promotion_mapping = {
      'premium' => GranblueEnums::PROMOTIONS[:Premium],
      'classic' => GranblueEnums::PROMOTIONS[:Classic],
      'classic_ii' => GranblueEnums::PROMOTIONS[:ClassicII],
      'flash' => GranblueEnums::PROMOTIONS[:Flash],
      'legend' => GranblueEnums::PROMOTIONS[:Legend],
      'valentines' => GranblueEnums::PROMOTIONS[:Valentine],
      'summer' => GranblueEnums::PROMOTIONS[:Summer],
      'halloween' => GranblueEnums::PROMOTIONS[:Halloween],
      'holiday' => GranblueEnums::PROMOTIONS[:Holiday],
      'collab' => GranblueEnums::PROMOTIONS[:Collab]
    }

    weapons_updated = 0
    summons_updated = 0
    errors = []

    # Query all gacha records
    gacha_records = ActiveRecord::Base.connection.execute('SELECT * FROM gacha')

    gacha_records.each do |record|
      # Build promotions array from boolean flags
      promotions = []
      promotion_mapping.each do |column, value|
        promotions << value if record[column] == true
      end

      drawable_type = record['drawable_type']
      drawable_id = record['drawable_id']

      if test_mode
        puts "#{drawable_type} #{drawable_id}: #{promotions.inspect}"
        if drawable_type == 'Weapon'
          weapons_updated += 1
        else
          summons_updated += 1
        end
        next
      end

      begin
        if drawable_type == 'Weapon'
          weapon = Weapon.find_by(id: drawable_id)
          if weapon
            weapon.update_column(:promotions, promotions)
            weapons_updated += 1
          else
            errors << "Weapon not found: #{drawable_id}"
          end
        elsif drawable_type == 'Summon'
          summon = Summon.find_by(id: drawable_id)
          if summon
            summon.update_column(:promotions, promotions)
            summons_updated += 1
          else
            errors << "Summon not found: #{drawable_id}"
          end
        end
      rescue StandardError => e
        errors << "Error updating #{drawable_type} #{drawable_id}: #{e.message}"
      end
    end

    puts "Weapons updated: #{weapons_updated}"
    puts "Summons updated: #{summons_updated}"
    puts "Errors: #{errors.count}"
    errors.each { |e| puts "  - #{e}" } if errors.any?
    puts "(TEST MODE - no changes made)" if test_mode
  end

  desc 'Verify migration by comparing gacha table to promotions arrays'
  task verify_migration: :environment do
    promotion_mapping = {
      'premium' => GranblueEnums::PROMOTIONS[:Premium],
      'classic' => GranblueEnums::PROMOTIONS[:Classic],
      'classic_ii' => GranblueEnums::PROMOTIONS[:ClassicII],
      'flash' => GranblueEnums::PROMOTIONS[:Flash],
      'legend' => GranblueEnums::PROMOTIONS[:Legend],
      'valentines' => GranblueEnums::PROMOTIONS[:Valentine],
      'summer' => GranblueEnums::PROMOTIONS[:Summer],
      'halloween' => GranblueEnums::PROMOTIONS[:Halloween],
      'holiday' => GranblueEnums::PROMOTIONS[:Holiday],
      'collab' => GranblueEnums::PROMOTIONS[:Collab]
    }

    mismatches = []
    gacha_records = ActiveRecord::Base.connection.execute('SELECT * FROM gacha')

    gacha_records.each do |record|
      expected_promotions = []
      promotion_mapping.each do |column, value|
        expected_promotions << value if record[column] == true
      end

      drawable_type = record['drawable_type']
      drawable_id = record['drawable_id']

      actual_promotions = if drawable_type == 'Weapon'
                            Weapon.find_by(id: drawable_id)&.promotions || []
                          else
                            Summon.find_by(id: drawable_id)&.promotions || []
                          end

      if expected_promotions.sort != actual_promotions.sort
        mismatches << {
          type: drawable_type,
          id: drawable_id,
          expected: expected_promotions.sort,
          actual: actual_promotions.sort
        }
      end
    end

    if mismatches.empty?
      puts "All #{gacha_records.count} records match!"
    else
      puts "Found #{mismatches.count} mismatches:"
      mismatches.each do |m|
        puts "  #{m[:type]} #{m[:id]}: expected #{m[:expected]}, got #{m[:actual]}"
      end
    end
  end
end
