# frozen_string_literal: true

module Api
  module V1
    class AwakeningBlueprint < ApiBlueprint
      field :name do |w|
        {
          en: w.name_en,
          ja: w.name_jp
        }
      end

      fields :slug, :object_type, :order
    end
  end
end
