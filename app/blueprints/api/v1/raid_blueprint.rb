# frozen_string_literal: true

module Api
  module V1
    class RaidBlueprint < ApiBlueprint
      view :nested do
        field :name do |raid|
          {
            en: raid.name_en,
            ja: raid.name_jp
          }
        end

        fields :slug, :level, :element
      end

      view :full do
        include_view :nested
        association :group, blueprint: RaidGroupBlueprint, view: :flat
      end
    end
  end
end
