# frozen_string_literal: true

module Api
  module V1
    class PhantomPlayersController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew, except: %i[gw_scores]
      before_action :set_crew_from_user, only: %i[gw_scores]
      before_action :authorize_crew_member!, only: %i[index confirm_claim decline_claim gw_scores]
      before_action :authorize_crew_officer!, only: %i[create bulk_create update destroy assign]
      before_action :set_phantom, only: %i[show update destroy assign confirm_claim decline_claim]
      before_action :set_phantom_for_scores, only: %i[gw_scores]

      # GET /crews/:crew_id/phantom_players
      def index
        phantoms = @crew.phantom_players.not_deleted.includes(:claimed_by).order(:name)
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

      # POST /crews/:crew_id/phantom_players/bulk_create
      def bulk_create
        phantoms = []

        ActiveRecord::Base.transaction do
          bulk_params[:phantom_players].each do |phantom_attrs|
            phantom = @crew.phantom_players.build(phantom_attrs.permit(:name, :granblue_id, :notes, :joined_at))
            phantom.save!
            phantoms << phantom
          end
        end

        render json: PhantomPlayerBlueprint.render(phantoms, root: :phantom_players), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
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

      # POST /crews/:crew_id/phantom_players/:id/decline_claim
      def decline_claim
        raise CrewErrors::NotClaimedByUserError unless @phantom.claimed_by == current_user

        @phantom.unassign!
        render json: PhantomPlayerBlueprint.render(@phantom, view: :with_claimed_by, root: :phantom_player)
      end

      # GET /crew/phantom_players/:id/gw_scores
      def gw_scores
        # Use SQL GROUP BY and SUM for efficient aggregation
        event_scores = GwIndividualScore
                       .joins(crew_gw_participation: :gw_event)
                       .where(phantom_player_id: @phantom.id)
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
          phantom: PhantomPlayerBlueprint.render_as_hash(@phantom),
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

      def set_phantom
        @phantom = @crew.phantom_players.find(params[:id])
      end

      def set_phantom_for_scores
        @phantom = @crew.phantom_players.find(params[:id])
      end

      def phantom_params
        params.require(:phantom_player).permit(:name, :granblue_id, :notes, :joined_at, :retired, :retired_at)
      end

      def bulk_params
        params.permit(phantom_players: %i[name granblue_id notes joined_at])
      end
    end
  end
end
