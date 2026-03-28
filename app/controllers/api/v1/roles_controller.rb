# frozen_string_literal: true

module Api
  module V1
    class RolesController < ApiController
      def index
        roles = Role.all
        roles = roles.for_slot(params[:slot_type]) if params[:slot_type].present?
        roles = roles.order(:sort_order, :name_en)

        render json: RoleBlueprint.render(roles)
      end
    end
  end
end
