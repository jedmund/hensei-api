# frozen_string_literal: true

# Character search: filters, text search and sort (see CatalogSearchQuery).
# Proficiency and race match either slot; +exclude+ drops owned characters
# from the add-to-collection list.
class CharacterSearchQuery < CatalogSearchQuery
  MODEL = Character
  FILTERS = {
    'rarity' => :rarity,
    'element' => :element,
    'season' => :season,
    'gender' => :gender,
    'proficiency1' => Filter.any_of(:proficiency1, :proficiency2),
    'race' => Filter.any_of(:race1, :race2),
    'series' => Filter.scope(:by_series)
  }.freeze

  def call
    exclude = @params[:exclude]
    exclude.present? ? super.where.not(id: exclude) : super
  end
end
