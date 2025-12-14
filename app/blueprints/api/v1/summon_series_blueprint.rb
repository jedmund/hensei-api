# frozen_string_literal: true

module Api
  module V1
    class SummonSeriesBlueprint < ApiBlueprint
      field :name do |ss|
        {
          en: ss.name_en,
          ja: ss.name_jp
        }
      end

      fields :slug, :order

      view :full do
        field :summon_count do |ss|
          ss.summons.count
        end
      end
    end
  end
end
