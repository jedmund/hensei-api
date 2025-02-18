# frozen_string_literal: true

# canonical.rb - Loads canonical seed data from CSV files into the database.
#
# This file is used to load canonical data for various models from CSV files
# located in db/seed/test. For models that reference other models by fixed IDs
# (e.g. Job, Guidebook, etc.), use the `use_id: true` option to preserve the CSV
# provided IDs (so that inter-model references remain correct).
#
# @example
#   load_csv_for(Character, 'characters_test.csv', :granblue_id)
#
#   # For objects that need to preserve the CSV "id" column:
#   load_csv_for(Job, 'jobs_test.csv', :granblue_id, use_id: true)
#
require 'csv'

##
# Processes specified columns in an attributes hash to booleans.
#
# @param attrs [Hash] The attributes hash.
# @param columns [Array<Symbol>] The list of columns to cast to boolean.
def process_booleans(attrs, columns)
  columns.each do |col|
    next unless attrs.key?(col) && attrs[col].present?
    # Use ActiveModel::Type::Boolean to cast the value.
    attrs[col] = ActiveModel::Type::Boolean.new.cast(attrs[col])
  end
end

##
# Processes specified columns in an attributes hash to dates.
#
# @param attrs [Hash] The attributes hash.
# @param columns [Array<Symbol>] The list of columns to parse as dates.
def process_dates(attrs, columns)
  columns.each do |col|
    next unless attrs.key?(col) && attrs[col].present?
    # Parse the date, or assign nil if parsing fails.
    attrs[col] = Date.parse(attrs[col]) rescue nil
  end
end

##
# Loads CSV data for the given model class.
#
# Reads a CSV file from the db/seed/test directory and uses the given unique_key
# to determine whether a record already exists. If the record exists, its attributes
# are not overwritten; otherwise, a new record is created.
#
# @param model_class [Class] The ActiveRecord model class to load data for.
# @param csv_filename [String] The CSV filename (located in db/seed/test).
# @param unique_key [Symbol] The attribute used to uniquely identify a record (default: :granblue_id).
# @param use_id [Boolean] If true, preserves the CSV id field instead of removing it (default: false).
#
# @return [void]
def load_csv_for(model_class, csv_filename, unique_key = :granblue_id, use_id: false)
  csv_file = Rails.root.join('db', 'seed', 'test', csv_filename)
  # puts "Loading #{model_class.name} data from #{csv_file}..."

  CSV.foreach(csv_file, headers: true) do |row|
    # Convert CSV row to a hash with symbolized keys.
    attrs = row.to_hash.symbolize_keys

    # Process known boolean columns.
    process_booleans(attrs, %i[flb ulb subaura limit transcendence])
    # Process known date columns. Extend this list as needed.
    process_dates(attrs, %i[release_date flb_date ulb_date transcendence_date created_at])

    # Clean up attribute values: trim whitespace and convert empty strings to nil.
    attrs.each { |k, v| attrs[k] = nil if v.is_a?(String) && v.strip.empty? }

    # Remove the :id attribute unless we want to preserve it (for fixed canonical IDs).
    attrs.except!(:id) unless use_id

    # Find or create the record based on the unique key.
    record = model_class.find_or_create_by!(unique_key => attrs[unique_key]) do |r|
      # Assign all attributes except the unique_key.
      r.assign_attributes(attrs.except(unique_key))
    end

    # puts "Loaded #{model_class.name}: #{record.public_send(unique_key)}"
  end
end

# Load canonical data for core models.
load_csv_for(Awakening, 'awakenings_test.csv', :id, use_id: true)
load_csv_for(Summon, 'summons_test.csv', :id, use_id: true)
load_csv_for(Weapon, 'weapons_test.csv', :id, use_id: true)
load_csv_for(Character, 'characters_test.csv', :id, use_id: true)

# Load additional canonical data that require preserving the provided IDs.
load_csv_for(Job, 'jobs_test.csv', :id, use_id: true)
load_csv_for(Guidebook, 'guidebooks_test.csv', :id, use_id: true)
load_csv_for(JobAccessory, 'job_accessories_test.csv', :id, use_id: true)
load_csv_for(JobSkill, 'job_skills_test.csv', :id, use_id: true)
load_csv_for(WeaponAwakening, 'weapon_awakenings_test.csv', :id, use_id: true)
load_csv_for(WeaponKey, 'weapon_keys_test.csv', :id, use_id: true)
