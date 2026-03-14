# frozen_string_literal: true

module Api
  module V1
    class RolesController < Api::V1::ApiController
      def index
        roles = Role.all
        roles = roles.for_slot(params[:slot_type]) if params[:slot_type].present?
        render json: RoleBlueprint.render(roles)
      end
    end
  end
end
