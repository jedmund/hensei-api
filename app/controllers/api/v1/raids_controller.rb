# frozen_string_literal: true

module Api
  module V1
    class RaidsController < Api::V1::ApiController
      before_action :set_raid, only: %i[show update destroy]
      before_action :ensure_editor_role, only: %i[create update destroy]

      # GET /raids
      def index
        raids = Raid.includes(:group)
        raids = apply_filters(raids)
        raids = raids.ordered

        render json: RaidBlueprint.render(raids, view: :nested)
      end

      # GET /raids/:id
      def show
        if @raid
          render json: RaidBlueprint.render(@raid, view: :full)
        else
          render json: { error: 'Raid not found' }, status: :not_found
        end
      end

      # POST /raids
      def create
        raid = Raid.new(raid_params)

        if raid.save
          render json: RaidBlueprint.render(raid, view: :full), status: :created
        else
          render_validation_error_response(raid)
        end
      end

      # PATCH/PUT /raids/:id
      def update
        if @raid.update(raid_params)
          render json: RaidBlueprint.render(@raid, view: :full)
        else
          render_validation_error_response(@raid)
        end
      end

      # DELETE /raids/:id
      def destroy
        if Party.where(raid_id: @raid.id).exists?
          render json: ErrorBlueprint.render(nil, error: {
            message: 'Cannot delete raid with associated parties',
            code: 'has_dependencies'
          }), status: :unprocessable_entity
        else
          @raid.destroy!
          head :no_content
        end
      end

      # GET /raids/groups (legacy endpoint)
      def groups
        render json: RaidGroupBlueprint.render(RaidGroup.includes(raids: :group).ordered, view: :full)
      end

      # Legacy alias for index
      def all
        index
      end

      private

      def set_raid
        @raid = Raid.find_by(slug: params[:id]) || Raid.find_by(id: params[:id])
      end

      def raid_params
        params.require(:raid).permit(:name_en, :name_jp, :level, :element, :slug, :group_id)
      end

      def apply_filters(scope)
        scope = scope.by_element(filter_params[:element]) if filter_params[:element].present?
        scope = scope.by_group(filter_params[:group_id]) if filter_params[:group_id].present?
        scope = scope.by_difficulty(filter_params[:difficulty]) if filter_params[:difficulty].present?
        scope = scope.by_hl(filter_params[:hl]) if filter_params[:hl].present?
        scope = scope.by_extra(filter_params[:extra]) if filter_params[:extra].present?
        scope = scope.with_guidebooks if filter_params[:guidebooks] == 'true'
        scope
      end

      def filter_params
        params.permit(:element, :group_id, :difficulty, :hl, :extra, :guidebooks)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[RAIDS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
