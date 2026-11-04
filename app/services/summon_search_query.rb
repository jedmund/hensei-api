# frozen_string_literal: true

# Summon search: filters, text search and sort (see CatalogSearchQuery).
class SummonSearchQuery < CatalogSearchQuery
  MODEL = Summon
  FILTERS = {
    'rarity' => :rarity,
    'element' => :element,
    'subaura' => :subaura,
    'series' => :summon_series_id,
    'promotions' => Filter::PROMOTIONS
  }.freeze
end
