# frozen_string_literal: true

module Api
  module V1
    class CrewGwParticipationsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :authorize_crew_member!
      before_action :set_participation, only: %i[show update]
      before_action :authorize_crew_officer!, only: %i[create update]

      # GET /crew/gw_participations
      def index
        participations = @crew.crew_gw_participations.includes(:gw_event).order('gw_events.start_date DESC')
        render json: CrewGwParticipationBlueprint.render(participations, view: :with_event, root: :crew_gw_participations)
      end

      # GET /crew/gw_participations/:id
      def show
        render json: CrewGwParticipationBlueprint.render(@participation, view: :with_individual_scores, root: :crew_gw_participation)
      end

      # POST /gw_events/:id/participations
      def create
        event = GwEvent.find(params[:id])

        participation = @crew.crew_gw_participations.build(gw_event: event)

        if participation.save
          render json: CrewGwParticipationBlueprint.render(participation, view: :with_event, root: :crew_gw_participation), status: :created
        else
          render_validation_error_response(participation)
        end
      end

      # PUT /crew/gw_participations/:id
      def update
        if @participation.update(participation_params)
          render json: CrewGwParticipationBlueprint.render(@participation, view: :with_event, root: :crew_gw_participation)
        else
          render_validation_error_response(@participation)
        end
      end

      private

      def set_crew
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end

      def set_participation
        @participation = @crew.crew_gw_participations.find(params[:id])
      end

      def participation_params
        params.require(:crew_gw_participation).permit(:preliminary_ranking, :final_ranking)
      end
    end
  end
end
