# frozen_string_literal: true

module Api
  module V1
    class RaidGroupBlueprint < ApiBlueprint
      view :flat do
        field :name do |group|
          {
            en: group.name_en,
            ja: group.name_jp
          }
        end

        fields :difficulty, :order, :section, :extra, :guidebooks, :hl
      end

      view :full do
        include_view :flat
        association :raids, blueprint: RaidBlueprint, view: :full
      end
    end
  end
end
