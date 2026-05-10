# frozen_string_literal: true

module Api
  module V1
    class DifficultyBlueprint < ApiBlueprint
      fields :name, :slug, :description, :min_score, :max_score, :sort_order, :color

      view :nested do
        fields :name, :slug, :color, :sort_order
      end

      view :list do
        include_view :nested
        fields :description, :min_score, :max_score
      end

      view :full do
        fields :created_at, :updated_at
      end
    end
  end
end
