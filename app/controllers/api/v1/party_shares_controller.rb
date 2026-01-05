# frozen_string_literal: true

module Api
  module V1
    class PartySharesController < Api::V1::ApiController
      before_action :restrict_access
      before_action :set_party
      before_action :authorize_party_owner!
      before_action :set_party_share, only: [:destroy]

      # GET /parties/:party_id/shares
      # List all shares for a party (only for owner)
      def index
        shares = @party.party_shares.includes(:shareable, :shared_by)
        render json: PartyShareBlueprint.render(shares, view: :with_shareable, root: :shares)
      end

      # POST /parties/:party_id/shares
      # Share a party with the current user's crew
      def create
        crew = current_user.crew
        raise PartyShareErrors::NotInCrewError unless crew

        # For now, users can only share to their own crew
        # Future: support party_share_params[:crew_id] for sharing to other crews
        share = PartyShare.new(
          party: @party,
          shareable: crew,
          shared_by: current_user
        )

        if share.save
          render json: PartyShareBlueprint.render(share, view: :with_shareable, root: :share), status: :created
        else
          render_validation_error_response(share)
        end
      end

      # DELETE /parties/:party_id/shares/:id
      # Remove a share
      def destroy
        @party_share.destroy!
        head :no_content
      end

      private

      def set_party
        @party = Party.find(params[:party_id])
      end

      def set_party_share
        @party_share = @party.party_shares.find(params[:id])
      end

      def authorize_party_owner!
        return if @party.user_id == current_user.id

        raise Api::V1::UnauthorizedError
      end

      def party_share_params
        params.require(:share).permit(:crew_id)
      end
    end
  end
end
