# frozen_string_literal: true

module Api
  module V1
    class SearchBlueprint < Blueprinter::Base
      identifier :searchable_id
      fields :searchable_type, :granblue_id, :name_en, :name_jp, :element

      # Character-specific fields (nil for non-characters)
      field :season do |document|
        document.searchable_type == 'Character' ? document.searchable&.season : nil
      end

      field :series do |document|
        next nil unless document.searchable_type == 'Character'

        character = document.searchable
        next nil unless character

        # Return series as array of objects with id, slug, and name
        character.character_series_records.ordered.map do |series|
          {
            id: series.id,
            slug: series.slug,
            name: { en: series.name_en, ja: series.name_jp }
          }
        end
      end
    end
  end
end
