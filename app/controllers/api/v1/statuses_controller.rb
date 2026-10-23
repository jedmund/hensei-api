# frozen_string_literal: true

module Api
  module V1
    class StatusesController < Api::V1::ApiController
      def index
        scope = Status.all
        scope = scope.where(category: params[:category]) if params[:category].present?
        scope = scope.in_family(params[:family]) if params[:family].present?

        render json: StatusBlueprint.render(scope, root: :statuses)
      end

      def show
        render json: StatusBlueprint.render(Status.find(params[:id]))
      end
    end
  end
end
