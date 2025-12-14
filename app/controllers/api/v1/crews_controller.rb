# frozen_string_literal: true

module Api
  module V1
    class CrewsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew, only: %i[show update members leave transfer_captain]
      before_action :require_crew!, only: %i[show update members]
      before_action :authorize_crew_member!, only: %i[show members]
      before_action :authorize_crew_officer!, only: %i[update]
      before_action :authorize_crew_captain!, only: %i[transfer_captain]

      # GET /crew or GET /crews/:id
      def show
        render json: CrewBlueprint.render(@crew, view: :full, root: :crew, current_user: current_user)
      end

      # POST /crews
      def create
        raise CrewErrors::AlreadyInCrewError if current_user.crew.present?

        @crew = Crew.new(crew_params)

        ActiveRecord::Base.transaction do
          @crew.save!
          CrewMembership.create!(crew: @crew, user: current_user, role: :captain)
        end

        render json: CrewBlueprint.render(@crew.reload, view: :full, root: :crew, current_user: current_user), status: :created
      end

      # PUT /crew
      def update
        if @crew.update(crew_params)
          render json: CrewBlueprint.render(@crew, view: :full, root: :crew, current_user: current_user)
        else
          render_validation_error_response(@crew)
        end
      end

      # GET /crew/members
      # Params:
      #   filter: 'active' (default), 'retired', 'phantom', 'all'
      def members
        filter = params[:filter]&.to_sym || :active

        case filter
        when :active
          members = @crew.active_memberships.includes(:user).order(role: :desc, created_at: :asc)
          phantoms = []
        when :retired
          members = @crew.crew_memberships.retired.includes(:user).order(retired_at: :desc)
          phantoms = []
        when :phantom
          members = []
          phantoms = @crew.phantom_players.includes(:claimed_by).order(:name)
        when :all
          members = @crew.crew_memberships.includes(:user).order(role: :desc, retired: :asc, created_at: :asc)
          phantoms = @crew.phantom_players.includes(:claimed_by).order(:name)
        else
          members = @crew.active_memberships.includes(:user).order(role: :desc, created_at: :asc)
          phantoms = []
        end

        render json: {
          members: CrewMembershipBlueprint.render_as_hash(members, view: :with_user),
          phantoms: PhantomPlayerBlueprint.render_as_hash(phantoms, view: :with_claimed_by)
        }
      end

      # POST /crew/leave
      def leave
        membership = current_user.active_crew_membership
        raise CrewErrors::NotInCrewError unless membership
        raise CrewErrors::CaptainCannotLeaveError if membership.captain?

        membership.retire!
        head :no_content
      end

      # POST /crews/:id/transfer_captain
      def transfer_captain
        new_captain_id = params[:user_id]
        new_captain_membership = @crew.active_memberships.find_by(user_id: new_captain_id)

        raise CrewErrors::MemberNotFoundError unless new_captain_membership

        ActiveRecord::Base.transaction do
          current_user.active_crew_membership.update!(role: :vice_captain)
          new_captain_membership.update!(role: :captain)
        end

        render json: CrewBlueprint.render(@crew.reload, view: :full, root: :crew, current_user: current_user)
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

      def require_crew!
        render_not_found_response('crew') unless @crew
      end
    end
  end
end
