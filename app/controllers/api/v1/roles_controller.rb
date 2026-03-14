# frozen_string_literal: true

module Api
  module V1
    class RolesController < Api::V1::ApiController
      def index
        roles = if params[:slot_type].present?
                  Role.for_slot(params[:slot_type])
                else
                  Role.all
                end

        render json: RoleBlueprint.render(roles.order(:sort_order), root: :roles)
      end
    end
  end
end
