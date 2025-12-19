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
      before_action :authorize_crew_officer!, only: %i[destroy history]
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

      # GET /crews/:crew_id/memberships/by_user/:user_id
      def history
        memberships = @crew.crew_memberships
                           .where(user_id: params[:user_id])
                           .order(created_at: :desc)
        render json: CrewMembershipBlueprint.render(memberships, view: :with_user, root: :memberships)
      end

      # GET /crew/memberships/:id/gw_scores
      def gw_scores
        # Find ALL memberships for this user in the crew (for boomerang players)
        all_memberships = @crew.crew_memberships.where(user_id: @membership.user_id)
        membership_ids = all_memberships.pluck(:id)

        # Get all crew GW events to identify gaps
        all_crew_events = @crew.crew_gw_participations
                               .joins(:gw_event)
                               .order('gw_events.event_number DESC')
                               .pluck('gw_events.id, gw_events.event_number, gw_events.element, gw_events.start_date, gw_events.end_date')

        # Get scores across all membership periods
        scores_by_event = GwIndividualScore
                          .joins(crew_gw_participation: :gw_event)
                          .where(crew_membership_id: membership_ids)
                          .group('gw_events.id')
                          .pluck('gw_events.id, SUM(gw_individual_scores.score)')
                          .to_h

        # Build event scores with gap markers
        event_scores = all_crew_events.map do |event_id, event_number, element, start_date, end_date|
          score = scores_by_event[event_id]
          {
            gw_event: { id: event_id, event_number: event_number, element: element, start_date: start_date, end_date: end_date },
            total_score: score&.to_i,
            in_crew: score.present?
          }
        end

        grand_total = event_scores.sum { |es| es[:total_score] || 0 }

        # Build membership periods for context
        membership_periods = all_memberships.order(created_at: :desc).map do |m|
          { id: m.id, joined_at: m.joined_at, retired_at: m.retired_at, retired: m.retired }
        end

        render json: {
          member: CrewMembershipBlueprint.render_as_hash(@membership, view: :with_user),
          event_scores: event_scores,
          grand_total: grand_total,
          membership_periods: membership_periods
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
