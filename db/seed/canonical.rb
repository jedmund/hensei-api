# frozen_string_literal: true

require 'csv'

# Helper: Process boolean columns.
def process_booleans(attrs, columns)
  columns.each do |col|
    next unless attrs.key?(col) && attrs[col].present?
    attrs[col] = ActiveModel::Type::Boolean.new.cast(attrs[col])
  end
end

# Helper: Process date columns.
def process_dates(attrs, columns)
  columns.each do |col|
    next unless attrs.key?(col) && attrs[col].present?
    attrs[col] = Date.parse(attrs[col]) rescue nil
  end
end

# Simplified CSV loader for a given model.
def load_csv_for(model_class, csv_filename, unique_key = :granblue_id)
  csv_file = Rails.root.join('db', 'seed', 'test', csv_filename)
  puts "Loading #{model_class.name} data from #{csv_file}..."
  CSV.foreach(csv_file, headers: true) do |row|
    attrs = row.to_hash.symbolize_keys
    process_booleans(attrs, %i[flb ulb subaura limit transcendence])
    process_dates(attrs, %i[release_date flb_date ulb_date transcendence_date])
    attrs.each { |k, v| attrs[k] = nil if v.is_a?(String) && v.strip.empty? }
    attrs.except!(:id)
    model_class.find_or_create_by!(unique_key => attrs[unique_key]) do |r|
      r.assign_attributes(attrs.except(unique_key))
    end
  end
end

# Load canonical data for each model.
load_csv_for(Awakening, 'awakenings_test.csv', :slug)
load_csv_for(Summon, 'summons_test.csv', :granblue_id)
load_csv_for(Weapon, 'weapons_test.csv', :granblue_id)
load_csv_for(Character, 'characters_test.csv', :granblue_id)
