# frozen_string_literal: true

# Guidebook search: a text search over names, or every guidebook.
class GuidebookSearchQuery < CatalogSearchQuery
  def call
    searched(Guidebook.all)
  end
end
