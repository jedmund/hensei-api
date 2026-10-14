# frozen_string_literal: true

# Loads the Arcarum Blessing catalogue from db/seed/solomonis/blessings.json
# (written by `bin/rails solomonis:generate_seeds`). Blessings are matched by
# slug and levels by (blessing, level). Rerunnable: it adds missing rows and
# fills empty columns, but never changes a value already in the database, so
# hand edits survive.
class LoadSolomonisBlessings < ActiveRecord::Migration[8.0]
  SEED_PATH = Rails.root.join('db/seed/solomonis/blessings.json')
  BLESSING_COLUMNS = %w[arcana_number name_en name_jp released].freeze
  LEVEL_COLUMNS = %w[description_en description_jp cost scintillas].freeze

  def self.load!(path = SEED_PATH)
    ArcarumBlessing.reset_column_information
    ArcarumBlessingLevel.reset_column_information

    data = JSON.parse(File.read(path))
    ActiveRecord::Base.transaction do
      data.fetch('blessings').each do |entry|
        blessing = ArcarumBlessing.find_or_initialize_by(slug: entry.fetch('slug'))
        fill_blanks(blessing, entry, BLESSING_COLUMNS)
        blessing.save!

        Array(entry['levels']).each do |level_entry|
          level = blessing.levels.find_or_initialize_by(level: level_entry.fetch('level'))
          fill_blanks(level, level_entry, LEVEL_COLUMNS)
          level.save!
        end
      end
    end
  end

  # Sets each column from the seed on a new record, and only nil columns on an
  # existing one. A null seed value never replaces anything.
  def self.fill_blanks(record, entry, columns)
    columns.each do |column|
      next if entry[column].nil?
      next unless record.new_record? || record[column].nil?

      record[column] = entry[column]
    end
  end

  def up
    unless File.exist?(SEED_PATH)
      say "Skipping: #{SEED_PATH} not found"
      return
    end

    self.class.load!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
