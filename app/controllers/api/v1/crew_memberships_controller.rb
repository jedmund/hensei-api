# frozen_string_literal: true

module Api
  module V1
    class CrewMembershipsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :set_membership, only: %i[update destroy promote demote]
      before_action :authorize_crew_officer!, only: %i[destroy]
      before_action :authorize_crew_captain!, only: %i[promote demote]
      before_action :authorize_membership_update!, only: %i[update]

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

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      end

      def set_membership
        @membership = @crew.crew_memberships.find(params[:id])
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
