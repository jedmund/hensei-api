# frozen_string_literal: true

module Api
  module V1
    class CrewInvitationsController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew, only: %i[index create]
      before_action :authorize_crew_officer!, only: %i[index create]
      before_action :set_invitation, only: %i[accept reject]

      # GET /crews/:crew_id/invitations
      # List pending invitations for a crew (officers only)
      def index
        invitations = @crew.crew_invitations.pending.includes(:user, :invited_by, :phantom_player)
        render json: CrewInvitationBlueprint.render(invitations, view: :with_user, root: :invitations)
      end

      # POST /crews/:crew_id/invitations
      # Send an invitation to a user (officers only)
      def create
        user = User.find_by(id: params[:user_id]) || User.find_by(username: params[:username])
        raise ActiveRecord::RecordNotFound, 'User not found' unless user
        raise CrewErrors::CannotInviteSelfError if user.id == current_user.id
        raise CrewErrors::AlreadyInCrewError if user.crew.present?

        # Check for existing pending invitation
        existing = @crew.crew_invitations.pending.find_by(user: user)
        raise CrewErrors::UserAlreadyInvitedError if existing

        invitation = @crew.crew_invitations.build(
          user: user,
          invited_by: current_user,
          phantom_player_id: params[:phantom_player_id]
        )

        if invitation.save
          render json: CrewInvitationBlueprint.render(invitation, view: :with_user, root: :invitation), status: :created
        else
          render_validation_error_response(invitation)
        end
      end

      # GET /invitations/pending
      # List pending invitations for current user
      def pending
        invitations = current_user.crew_invitations.active.includes(:crew, :invited_by, :phantom_player)
        render json: CrewInvitationBlueprint.render(invitations, view: :for_invitee, root: :invitations)
      end

      # POST /invitations/:id/accept
      def accept
        raise CrewErrors::InvitationNotFoundError unless @invitation.user_id == current_user.id

        @invitation.accept!
        render json: CrewBlueprint.render(current_user.crew, view: :full, root: :crew)
      end

      # POST /invitations/:id/reject
      def reject
        raise CrewErrors::InvitationNotFoundError unless @invitation.user_id == current_user.id

        @invitation.reject!
        head :no_content
      end

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      end

      def set_invitation
        @invitation = CrewInvitation.find(params[:id])
      end
    end
  end
end
