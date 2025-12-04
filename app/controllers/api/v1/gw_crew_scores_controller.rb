# frozen_string_literal: true

module Api
  module V1
    class GwCrewScoresController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :authorize_crew_officer!
      before_action :set_participation
      before_action :set_score, only: %i[update destroy]

      # POST /crew/gw_participations/:gw_participation_id/crew_scores
      def create
        score = @participation.gw_crew_scores.build(score_params)

        if score.save
          render json: GwCrewScoreBlueprint.render(score, root: :gw_crew_score), status: :created
        else
          render_validation_error_response(score)
        end
      end

      # PUT /crew/gw_participations/:gw_participation_id/crew_scores/:id
      def update
        if @score.update(score_params)
          render json: GwCrewScoreBlueprint.render(@score, root: :gw_crew_score)
        else
          render_validation_error_response(@score)
        end
      end

      # DELETE /crew/gw_participations/:gw_participation_id/crew_scores/:id
      def destroy
        @score.destroy!
        head :no_content
      end

      private

      def set_crew
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end

      def set_participation
        @participation = @crew.crew_gw_participations.find(params[:gw_participation_id])
      end

      def set_score
        @score = @participation.gw_crew_scores.find(params[:id])
      end

      def score_params
        params.require(:crew_score).permit(:round, :crew_score, :opponent_score, :opponent_name, :opponent_granblue_id)
      end
    end
  end
end
