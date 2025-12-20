# frozen_string_literal: true

module Api
  module V1
    class RaidGroupsController < Api::V1::ApiController
      before_action :set_raid_group, only: %i[show update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /raid_groups
      def index
        groups = RaidGroup.includes(:raids).ordered
        render json: RaidGroupBlueprint.render(groups, view: :full)
      end

      # GET /raid_groups/:id
      def show
        if @raid_group
          render json: RaidGroupBlueprint.render(@raid_group, view: :full)
        else
          render json: { error: 'Raid group not found' }, status: :not_found
        end
      end

      # POST /raid_groups
      def create
        raid_group = RaidGroup.new(raid_group_params)

        if raid_group.save
          render json: RaidGroupBlueprint.render(raid_group, view: :full), status: :created
        else
          render_validation_error_response(raid_group)
        end
      end

      # PATCH/PUT /raid_groups/:id
      def update
        if @raid_group.update(raid_group_params)
          render json: RaidGroupBlueprint.render(@raid_group, view: :full)
        else
          render_validation_error_response(@raid_group)
        end
      end

      # DELETE /raid_groups/:id
      def destroy
        if @raid_group.raids.exists?
          render json: ErrorBlueprint.render(nil, error: {
            message: 'Cannot delete group with associated raids',
            code: 'has_dependencies'
          }), status: :unprocessable_entity
        else
          @raid_group.destroy!
          head :no_content
        end
      end

      private

      def set_raid_group
        @raid_group = RaidGroup.find_by(id: params[:id])
      end

      def raid_group_params
        params.require(:raid_group).permit(
          :name_en, :name_jp, :difficulty, :order, :section, :extra, :hl, :guidebooks, :unlimited
        )
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[RAID_GROUPS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
