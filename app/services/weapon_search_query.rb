# frozen_string_literal: true

# Weapon search: filters, text search and sort (see CatalogSearchQuery).
class WeaponSearchQuery < CatalogSearchQuery
  MODEL = Weapon
  FILTERS = {
    'rarity' => :rarity,
    'element' => :element,
    'proficiency1' => :proficiency,
    'series' => :weapon_series_id,
    'extra' => :extra,
    'promotions' => Filter::PROMOTIONS
  }.freeze
end
