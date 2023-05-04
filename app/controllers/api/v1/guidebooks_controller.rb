# frozen_string_literal: true

module Api
  module V1
    class GuidebooksController < Api::V1::ApiController
      def all
        render json: GuidebookBlueprint.render(Guidebook.all)
      end
    end
  end
end
