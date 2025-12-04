# frozen_string_literal: true

module Api
  module V1
    class CrewsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew, only: %i[show update members leave transfer_captain]
      before_action :authorize_crew_member!, only: %i[show members]
      before_action :authorize_crew_officer!, only: %i[update]
      before_action :authorize_crew_captain!, only: %i[transfer_captain]

      # GET /crew or GET /crews/:id
      def show
        render json: CrewBlueprint.render(@crew, view: :full, root: :crew)
      end

      # POST /crews
      def create
        raise AlreadyInCrewError if current_user.crew.present?

        @crew = Crew.new(crew_params)

        ActiveRecord::Base.transaction do
          @crew.save!
          CrewMembership.create!(crew: @crew, user: current_user, role: :captain)
        end

        render json: CrewBlueprint.render(@crew, view: :full, root: :crew), status: :created
      end

      # PUT /crew
      def update
        if @crew.update(crew_params)
          render json: CrewBlueprint.render(@crew, view: :full, root: :crew)
        else
          render_validation_error_response(@crew)
        end
      end

      # GET /crew/members
      def members
        members = @crew.active_memberships.includes(:user).order(role: :desc, created_at: :asc)
        render json: CrewMembershipBlueprint.render(members, view: :with_user, root: :members)
      end

      # POST /crew/leave
      def leave
        raise NotInCrewError unless @crew

        membership = current_user.active_crew_membership
        raise CaptainCannotLeaveError if membership.captain?

        membership.retire!
        head :no_content
      end

      # POST /crews/:id/transfer_captain
      def transfer_captain
        new_captain_id = params[:user_id]
        new_captain_membership = @crew.active_memberships.find_by(user_id: new_captain_id)

        raise MemberNotFoundError unless new_captain_membership

        ActiveRecord::Base.transaction do
          current_user.active_crew_membership.update!(role: :vice_captain)
          new_captain_membership.update!(role: :captain)
        end

        render json: CrewBlueprint.render(@crew.reload, view: :full, root: :crew)
      end

      private

      def set_crew
        @crew = if params[:id]
                  Crew.find(params[:id])
                else
                  current_user&.crew
                end
      end

      def crew_params
        params.require(:crew).permit(:name, :gamertag, :granblue_crew_id, :description)
      end
    end
  end
end
