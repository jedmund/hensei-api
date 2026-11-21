# frozen_string_literal: true

module Api
  module V1
    # A Wonders page category, for GET /wonders
    class WonderCategoryBlueprint < ApiBlueprint
      fields :granblue_id, :category_type, :sort_order

      field :name do |category|
        { en: category.name_en, ja: category.name_jp.presence || category.name_en }
      end
    end
  end
end
