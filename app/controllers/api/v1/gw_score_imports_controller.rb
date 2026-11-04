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
        members = list_param(:members)
        participation = @crew.crew_gw_participations.find_or_create_by!(event: event)

        result = GwScoreImport.new(@crew).import(participation, members,
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
        render json: GwScoreImport.new(@crew).preview(list_param(:granblue_ids))
      end

      private

      # The array at params[key]; a missing or non-array value is a 422
      # (ParameterMissing) rather than a 500. An empty array is allowed.
      def list_param(key)
        value = params[key]
        raise ActionController::ParameterMissing, key unless value.is_a?(Array)

        value
      end

      def set_crew
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end
    end
  end
end
