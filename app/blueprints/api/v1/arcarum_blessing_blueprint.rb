# frozen_string_literal: true

module Api
  module V1
    # An Arcarum Blessing. The default view is the reference embedded in a
    # party's loadout; :catalogue adds release state and levels.
    class ArcarumBlessingBlueprint < ApiBlueprint
      fields :slug, :arcana_number

      field :name do |blessing|
        { en: blessing.name_en, ja: blessing.name_jp }
      end

      view :catalogue do
        field :released
        association :levels, blueprint: ArcarumBlessingLevelBlueprint
      end
    end
  end
end
