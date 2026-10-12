# frozen_string_literal: true

module Api
  module V1
    # One level of an Arcarum Blessing (Evoking Solomonis catalogue).
    class ArcarumBlessingLevelBlueprint < ApiBlueprint
      fields :level, :cost, :scintillas

      field :description do |level|
        { en: level.description_en, ja: level.description_jp }
      end
    end
  end
end
