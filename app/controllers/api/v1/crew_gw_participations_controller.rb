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
        participations = @crew.crew_gw_participations.eager_load(:event).order('events.starts_at DESC')
        render json: CrewGwParticipationBlueprint.render(participations, view: :with_event, root: :crew_gw_participations)
      end

      # GET /crew/gw_participations/:id
      def show
        render json: CrewGwParticipationBlueprint.render(@participation, view: :with_individual_scores,
                                                                         root: :crew_gw_participation,
                                                                         current_user: current_user)
      end

      # GET /crew/gw_participations/by_event/:event_id
      def by_event
        event = find_gw_event(params.expect(:event_id))
        return render json: { gw_event: nil, crew_gw_participation: nil, members_during_event: [] } unless event

        participation = event_participation(event)

        render json: {
          gw_event: GwEventBlueprint.render_as_hash(event),
          crew_gw_participation: participation && CrewGwParticipationBlueprint.render_as_hash(
            participation, view: :with_individual_scores, current_user: current_user
          ),
          members_during_event: event_members(event),
          phantom_players: event_phantoms(event)
        }
      end

      # POST /gw_events/:id/participations
      def create
        event = Event.unite_and_fight.find(params.expect(:id))

        participation = @crew.crew_gw_participations.build(event: event)

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
        @participation = @crew.crew_gw_participations.find(params.expect(:id))
      end

      # Looked up by event_number (digits) or id (UUID)
      def find_gw_event(event_id)
        if event_id.match?(/\A\d+\z/)
          Event.unite_and_fight.find_by(event_number: event_id)
        else
          Event.unite_and_fight.find_by(id: event_id)
        end
      end

      def event_participation(event)
        @crew.crew_gw_participations
             .includes(:event,
                       gw_individual_scores: [{ crew_membership: { user: { active_crew_membership: :crew } } }, :phantom_player])
             .find_by(event: event)
      end

      # Members active during the event plus current ones (for historical
      # score entry), flagged by whether they were active during it.
      def event_members(event)
        during = @crew.crew_memberships.active_during(event.start_date, event.end_date)
        active_ids = during.pluck(:id).to_set
        members = @crew.crew_memberships
                       .includes(user: { active_crew_membership: :crew })
                       .active_during(event.start_date, event.end_date)
                       .or(@crew.crew_memberships.where(retired: false))

        members.map do |m|
          CrewMembershipBlueprint.render_as_hash(m, view: :with_user).merge(active_during_event: active_ids.include?(m.id))
        end
      end

      # The same for phantom players, leaving out deleted ones
      def event_phantoms(event)
        phantoms = @crew.phantom_players.not_deleted
        active_ids = phantoms.active_during(event.start_date, event.end_date).pluck(:id).to_set

        phantoms.active_during(event.start_date, event.end_date).or(phantoms.where(retired: false)).map do |p|
          PhantomPlayerBlueprint.render_as_hash(p).merge(active_during_event: active_ids.include?(p.id))
        end
      end

      def participation_params
        params.expect(crew_gw_participation: %i[preliminary_ranking final_ranking])
      end
    end
  end
end
