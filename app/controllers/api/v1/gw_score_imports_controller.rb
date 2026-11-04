# frozen_string_literal: true

module Api
  module V1
    class GwScoreImportsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :authorize_crew_officer!

      # POST /crew/import_gw_scores
      # Params: { event_number:, round:, is_cumulative:, members: [{ granblue_id:, name:, score: }] }
      def create
        event = Event.unite_and_fight.find_by!(event_number: params.expect(:event_number))
        participation = @crew.crew_gw_participations.find_or_create_by!(event: event)

        result = GwScoreImport.new(@crew).import(participation, params[:members],
                                                 round: params[:round],
                                                 cumulative: params[:is_cumulative] || false,
                                                 recorded_by: current_user)

        render json: {
          imported: result.imported,
          phantoms_created: result.phantoms_created,
          errors: result.errors
        }, status: result.errors.empty? ? :created : :multi_status
      end

      # POST /crew/preview_gw_phantoms
      # Params: { granblue_ids: ["12345", "67890", ...] }
      def preview
        render json: GwScoreImport.new(@crew).preview(params[:granblue_ids])
      end

      private

      def set_crew
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end
    end
  end
end
