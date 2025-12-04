# frozen_string_literal: true

module Api
  module V1
    class PhantomPlayersController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :authorize_crew_member!, only: %i[index confirm_claim]
      before_action :authorize_crew_officer!, only: %i[create update destroy assign]
      before_action :set_phantom, only: %i[show update destroy assign confirm_claim]

      # GET /crews/:crew_id/phantom_players
      def index
        phantoms = @crew.phantom_players.includes(:claimed_by).order(:name)
        render json: PhantomPlayerBlueprint.render(phantoms, view: :with_claimed_by, root: :phantom_players)
      end

      # GET /crews/:crew_id/phantom_players/:id
      def show
        render json: PhantomPlayerBlueprint.render(@phantom, view: :with_scores, root: :phantom_player)
      end

      # POST /crews/:crew_id/phantom_players
      def create
        phantom = @crew.phantom_players.build(phantom_params)

        if phantom.save
          render json: PhantomPlayerBlueprint.render(phantom, root: :phantom_player), status: :created
        else
          render_validation_error_response(phantom)
        end
      end

      # PUT /crews/:crew_id/phantom_players/:id
      def update
        if @phantom.update(phantom_params)
          render json: PhantomPlayerBlueprint.render(@phantom, view: :with_claimed_by, root: :phantom_player)
        else
          render_validation_error_response(@phantom)
        end
      end

      # DELETE /crews/:crew_id/phantom_players/:id
      def destroy
        @phantom.destroy!
        head :no_content
      end

      # POST /crews/:crew_id/phantom_players/:id/assign
      def assign
        user = User.find(params[:user_id])
        @phantom.assign_to(user)
        render json: PhantomPlayerBlueprint.render(@phantom, view: :with_claimed_by, root: :phantom_player)
      end

      # POST /crews/:crew_id/phantom_players/:id/confirm_claim
      def confirm_claim
        @phantom.confirm_claim!(current_user)
        render json: PhantomPlayerBlueprint.render(@phantom, view: :with_claimed_by, root: :phantom_player)
      end

      private

      def set_crew
        @crew = Crew.find(params[:crew_id])
      end

      def set_phantom
        @phantom = @crew.phantom_players.find(params[:id])
      end

      def phantom_params
        params.require(:phantom_player).permit(:name, :granblue_id, :notes, :joined_at)
      end
    end
  end
end
