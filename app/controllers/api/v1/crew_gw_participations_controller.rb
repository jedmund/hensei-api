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
        render json: CrewGwParticipationBlueprint.render(@participation, view: :with_individual_scores, root: :crew_gw_participation, current_user: current_user)
      end

      # GET /crew/gw_participations/by_event/:event_id
      def by_event
        # Support lookup by event_id (UUID) or event_number (integer)
        event = if params[:event_id].match?(/\A\d+\z/)
                  GwEvent.find_by(event_number: params[:event_id])
                else
                  GwEvent.find_by(id: params[:event_id])
                end

        return render json: { gw_event: nil, crew_gw_participation: nil, members_during_event: [] } unless event

        participation = @crew.crew_gw_participations
                             .includes(:gw_event, gw_individual_scores: [{ crew_membership: :user }, :phantom_player])
                             .find_by(gw_event: event)

        # Get all members who were active during the event (includes retired members who left after event started)
        # Also include all currently active members for score entry purposes
        # Uses joined_at (editable) for historical accuracy
        members_during_event = @crew.crew_memberships
                                    .includes(:user)
                                    .active_during(event.start_date, event.end_date)

        # Get all phantom players who were active during the event (excludes claimed/deleted phantoms)
        phantom_players = @crew.phantom_players.not_deleted.active_during(event.start_date, event.end_date)

        render json: {
          gw_event: GwEventBlueprint.render_as_hash(event),
          crew_gw_participation: participation ? CrewGwParticipationBlueprint.render_as_hash(participation, view: :with_individual_scores, current_user: current_user) : nil,
          members_during_event: CrewMembershipBlueprint.render_as_hash(members_during_event, view: :with_user),
          phantom_players: PhantomPlayerBlueprint.render_as_hash(phantom_players)
        }
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
