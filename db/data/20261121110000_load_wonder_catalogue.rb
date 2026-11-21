# frozen_string_literal: true

# Loads the Wonders catalogue from db/data/wonders/catalogue.json (written
# offline by `bin/rails wonders:generate_seed`). Self-contained: it reads only
# that file, with no network and no sources rows, since production has none.
#
# Rerunnable, and the seed is authoritative: categories and Wonders are
# upserted by granblue_id, effects by action_id (or, for wiki-only effects
# without one, by the Wonder and position), level bonuses by level and
# evolution caps by evolution. Rows the seed no longer lists for a Wonder are
# removed; Wonders and categories are never deleted, since collections and
# teams reference them.
class LoadWonderCatalogue < ActiveRecord::Migration[8.1]
  SEED_PATH = Rails.root.join('db/data/wonders/catalogue.json')
  CATEGORY_COLUMNS = %w[name_en name_jp category_type sort_order].freeze
  WONDER_COLUMNS = %w[name_en name_jp description_en description_jp kind max_level max_evolution element
                      battle_relevant hidden_in_unite_and_fight sort_order].freeze
  MODELS = [WonderCategory, Wonder, WonderEffect, WonderEffectLink, WonderLevelBonus, WonderEvolutionCap].freeze

  def self.load!(path = SEED_PATH)
    MODELS.each(&:reset_column_information)
    data = JSON.parse(File.read(path))

    ActiveRecord::Base.transaction do
      categories = data.fetch('categories').to_h do |entry|
        category = WonderCategory.find_or_initialize_by(granblue_id: entry.fetch('granblue_id'))
        category.assign_attributes(entry.slice(*CATEGORY_COLUMNS))
        category.save!
        [category.granblue_id, category]
      end

      data.fetch('wonders').each { |entry| load_wonder(entry, categories) }
      WonderEffect.where(action_id: nil).where.missing(:wonder_effect_links).delete_all
    end
  end

  def self.load_wonder(entry, categories)
    wonder = Wonder.find_or_initialize_by(granblue_id: entry.fetch('granblue_id'))
    wonder.assign_attributes(entry.slice(*WONDER_COLUMNS))
    wonder.wonder_category = categories.fetch(entry.fetch('category'))
    wonder.save!

    load_effects(wonder, entry.fetch('effects'))
    replace_rows(wonder.level_bonuses, entry.fetch('level_bonuses'), 'level', %w[stat value])
    replace_rows(wonder.evolution_caps, entry.fetch('evolution_caps'), 'evolution', %w[max_level])
  end

  def self.load_effects(wonder, entries)
    links = wonder.wonder_effect_links.includes(:wonder_effect).index_by(&:position)
    entries.each do |entry|
      position = entry.fetch('position')
      effect = if entry['action_id']
                 WonderEffect.find_or_initialize_by(action_id: entry['action_id'])
               else
                 existing = links[position]&.wonder_effect
                 existing && existing.action_id.nil? ? existing : WonderEffect.new
               end
      effect.assign_attributes(text_en: entry['text_en'], text_jp: entry['text_jp'], details: entry['details'] || {})
      effect.save!

      link = links[position] || wonder.wonder_effect_links.build(position: position)
      link.wonder_effect = effect
      link.save!
    end
    wonder.wonder_effect_links.where.not(position: entries.pluck('position')).delete_all
  end

  # Upserts a Wonder's child rows by key and removes the ones the seed doesn't list
  def self.replace_rows(association, entries, key, columns)
    existing = association.index_by { |row| row[key] }
    entries.each do |entry|
      row = existing[entry.fetch(key)] || association.build(key => entry.fetch(key))
      row.assign_attributes(entry.slice(*columns))
      row.save!
    end
    association.where.not(key => entries.pluck(key)).delete_all
  end

  def up
    self.class.load!
  end

  def down
    # Nothing to undo: collections and teams reference the catalogue.
  end
end
