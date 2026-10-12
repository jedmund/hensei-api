# frozen_string_literal: true

# Loads the Evoking Solomonis guide effect catalogue from
# db/seed/solomonis/guide_effects.json, keyed by granblue_id (the game's
# status_id). character_granblue_id resolves to the Evoker's character row.
# Rerunnable: it adds missing effects and fills empty columns (null, or an
# empty target list), but never changes a value already in the database.
class LoadSolomonisGuideEffects < ActiveRecord::Migration[8.0]
  SEED_PATH = Rails.root.join('db/seed/solomonis/guide_effects.json')
  COLUMNS = %w[rarity stackable name_en name_jp icon_category icon_type target_type target_values
               availability type_tags effect_tags].freeze

  def self.load!(path = SEED_PATH)
    SolomonisGuideEffect.reset_column_information

    data = JSON.parse(File.read(path))
    ActiveRecord::Base.transaction do
      data.fetch('guide_effects').each do |entry|
        effect = SolomonisGuideEffect.find_or_initialize_by(granblue_id: entry.fetch('granblue_id'))
        COLUMNS.each do |column|
          value = entry[column]
          next if value.nil?
          next unless effect.new_record? || blank_column?(effect, column)

          effect[column] = value
        end
        effect.character_id ||= character_id_for(entry['character_granblue_id'])
        effect.save!
      end
    end
  end

  def self.blank_column?(effect, column)
    current = effect[column]
    column == 'target_values' ? current.blank? : current.nil?
  end

  def self.character_id_for(granblue_id)
    return nil if granblue_id.blank?

    Character.where(granblue_id: granblue_id.to_s, style_swap: false).pick(:id)
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
