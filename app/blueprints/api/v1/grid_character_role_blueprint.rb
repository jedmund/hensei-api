# frozen_string_literal: true

module Api
  module V1
    class GridCharacterRoleBlueprint < ApiBlueprint
      fields :id, :name_en, :name_jp, :sort_order

      # Versioned so re-uploads bust browser and CDN caches
      field :icon_key do |role|
        role.versioned_icon_key
      end
    end
  end
end
