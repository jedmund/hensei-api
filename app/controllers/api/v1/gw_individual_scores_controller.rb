# frozen_string_literal: true

module Api
  module V1
    class GwIndividualScoresController < Api::V1::ApiController
      include CrewAuthorizationConcern

      before_action :restrict_access
      before_action :set_crew
      before_action :authorize_crew_member!
      before_action :set_participation
      before_action :set_score, only: %i[update destroy]

      # POST /crew/gw_participations/:participation_id/individual_scores
      def create
        # Members can only record their own scores, officers can record anyone's
        membership_id = score_params[:crew_membership_id]
        unless can_record_score_for?(membership_id)
          raise Api::V1::UnauthorizedError
        end

        score = @participation.gw_individual_scores.build(score_params)
        score.recorded_by = current_user

        if score.save
          render json: GwIndividualScoreBlueprint.render(score, view: :with_member, root: :individual_score), status: :created
        else
          render_validation_error_response(score)
        end
      end

      # PUT /crew/gw_participations/:participation_id/individual_scores/:id
      def update
        unless can_record_score_for?(@score.crew_membership_id)
          raise Api::V1::UnauthorizedError
        end

        if @score.update(score_params.except(:crew_membership_id))
          render json: GwIndividualScoreBlueprint.render(@score, view: :with_member, root: :individual_score)
        else
          render_validation_error_response(@score)
        end
      end

      # DELETE /crew/gw_participations/:participation_id/individual_scores/:id
      def destroy
        unless can_record_score_for?(@score.crew_membership_id)
          raise Api::V1::UnauthorizedError
        end

        @score.destroy!
        head :no_content
      end

      # POST /crew/gw_participations/:participation_id/individual_scores/batch
      def batch
        authorize_crew_officer!

        scores_params = params.require(:scores)
        results = []
        errors = []

        scores_params.each_with_index do |score_data, index|
          score = @participation.gw_individual_scores.find_or_initialize_by(
            crew_membership_id: score_data[:crew_membership_id],
            round: score_data[:round]
          )
          score.assign_attributes(
            score: score_data[:score],
            is_cumulative: score_data[:is_cumulative] || false,
            recorded_by: current_user
          )

          if score.save
            results << score
          else
            errors << { index: index, errors: score.errors.full_messages }
          end
        end

        if errors.empty?
          render json: GwIndividualScoreBlueprint.render(results, view: :with_member, root: :individual_scores), status: :created
        else
          render json: { individual_scores: GwIndividualScoreBlueprint.render_as_hash(results, view: :with_member), errors: errors },
                 status: :multi_status
        end
      end

      private

      def set_crew
        @crew = current_user.crew
        raise CrewErrors::NotInCrewError unless @crew
      end

      def set_participation
        @participation = @crew.crew_gw_participations.find(params[:participation_id])
      end

      def set_score
        @score = @participation.gw_individual_scores.find(params[:id])
      end

      def score_params
        params.require(:individual_score).permit(:crew_membership_id, :round, :score, :is_cumulative)
      end

      def can_record_score_for?(membership_id)
        return true if current_user.crew_officer?

        # Regular members can only record their own scores
        current_user.active_crew_membership&.id == membership_id
      end
    end
  end
end
