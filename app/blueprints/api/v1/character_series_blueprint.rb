# frozen_string_literal: true

module Api
  module V1
    class CharacterSeriesBlueprint < ApiBlueprint
      field :name do |cs|
        {
          en: cs.name_en,
          ja: cs.name_jp
        }
      end

      fields :slug, :order

      view :full do
        field :character_count do |cs|
          cs.characters.count
        end
      end
    end
  end
end
