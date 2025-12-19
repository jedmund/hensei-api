# frozen_string_literal: true

module Api
  module V1
    class CrewMembershipsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew, except: %i[gw_scores]
      before_action :set_crew_from_user, only: %i[gw_scores]
      before_action :set_membership, only: %i[update destroy promote demote]
      before_action :set_membership_for_scores, only: %i[gw_scores]
      before_action :authorize_crew_officer!, only: %i[destroy]
      before_action :authorize_crew_captain!, only: %i[promote demote]
      before_action :authorize_membership_update!, only: %i[update]
      before_action :authorize_crew_member!, only: %i[gw_scores]

      # PUT /crews/:crew_id/memberships/:id
      def update
        allowed_params = if current_user.crew_captain?
                           membership_params
                         else
                           membership_params.slice(:joined_at)
                         end

        if @membership.update(allowed_params)
          render json: CrewMembershipBlueprint.render(@membership, view: :with_user, root: :membership)
        else
          render_validation_error_response(@membership)
        end
      end

      # DELETE /crews/:crew_id/memberships/:id
      def destroy
        raise CrewErrors::CannotRemoveCaptainError if @membership.captain?

        @membership.retire!
        head :no_content
      end

      # POST /crews/:crew_id/memberships/:id/promote
      def promote
        raise CrewErrors::CannotRemoveCaptainError if @membership.captain?

        # Check vice captain limit
        current_vc_count = @crew.crew_memberships.where(role: :vice_captain, retired: false).count
        raise CrewErrors::ViceCaptainLimitError if current_vc_count >= 3 && !@membership.vice_captain?

        @membership.update!(role: :vice_captain)
        render json: CrewMembershipBlueprint.render(@membership, view: :with_user, root: :membership)
      end

      # POST /crews/:crew_id/memberships/:id/demote
      def demote
        raise CrewErrors::CannotDemoteCaptainError if @membership.captain?

        @membership.update!(role: :member)
        render json: CrewMembershipBlueprint.render(@membership, view: :with_user, root: :membership)
      end

      # GET /crew/memberships/:id/gw_scores
      def gw_scores
        # Use SQL GROUP BY and SUM for efficient aggregation
        event_scores = GwIndividualScore
                       .joins(crew_gw_participation: :gw_event)
                       .where(crew_membership_id: @membership.id)
                       .group('gw_events.id, gw_events.event_number, gw_events.element, gw_events.start_date, gw_events.end_date')
                       .order('gw_events.event_number DESC')
                       .pluck('gw_events.id, gw_events.event_number, gw_events.element, gw_events.start_date, gw_events.end_date, SUM(gw_individual_scores.score)')
                       .map do |id, event_number, element, start_date, end_date, total_score|
                         {
                           gw_event: { id: id, event_number: event_number, element: element, start_date: start_date, end_date: end_date },
                           total_score: total_score.to_i
                         }
                       end

        grand_total = event_scores.sum { |es| es[:total_score] }

        render json: {
          member: CrewMembershipBlueprint.render_as_hash(@membership, view: :with_user),
          event_scores: event_scores,
          grand_total: grand_total
        }
      end

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      end

      def set_crew_from_user
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end

      def set_membership
        @membership = @crew.crew_memberships.find(params[:id])
      end

      def set_membership_for_scores
        # Try to find by username first, then fall back to ID
        @membership = @crew.crew_memberships.joins(:user).find_by(users: { username: params[:id] }) ||
                      @crew.crew_memberships.find(params[:id])
      end

      def membership_params
        params.require(:membership).permit(:role, :joined_at, :retired, :retired_at)
      end

      def authorize_membership_update!
        # Officers can update any membership's joined_at
        # Captains can update anything
        return if current_user.crew_captain?
        return if current_user.crew_officer?

        raise Api::V1::UnauthorizedError
      end
    end
  end
end
