# frozen_string_literal: true

module Api
  module V1
    class PhantomClaimsController < Api::V1::ApiController
      before_action :restrict_access

      # GET /pending_phantom_claims
      # Returns phantom players assigned to the current user that are pending confirmation
      def index
        phantoms = PhantomPlayer
          .includes(:crew, :claimed_by)
          .where(claimed_by: current_user, claim_confirmed: false)
          .order(created_at: :desc)

        render json: PhantomPlayerBlueprint.render(phantoms, view: :with_crew, root: :phantom_claims)
      end
    end
  end
end
