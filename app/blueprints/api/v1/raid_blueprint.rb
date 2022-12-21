# frozen_string_literal: true

module Api
  module V1
    class RaidBlueprint < ApiBlueprint
      fields :id, :slug, :level, :group, :element
      field :name do |raid|
        {
          en: raid.name_en,
          ja: raid.name_jp
        }
      end
    end
  end
end
