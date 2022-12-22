# frozen_string_literal: true

module Api
  module V1
    class RaidBlueprint < ApiBlueprint
      field :name do |raid|
        {
          en: raid.name_en,
          ja: raid.name_jp
        }
      end

      fields :slug, :level, :group, :element
    end
  end
end
