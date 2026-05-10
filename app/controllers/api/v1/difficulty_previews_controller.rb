# frozen_string_literal: true

module Api
  module V1
    ##
    # Editor-only endpoint that runs the difficulty calculator against a party
    # without persisting the result. Used in the Database editor UI to test
    # rule changes against real parties.
    class DifficultyPreviewsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role

      def create
        shortcode = params[:shortcode] || params.dig(:preview, :shortcode)
        return render json: { error: 'shortcode is required' }, status: :unprocessable_entity if shortcode.blank?

        party = Party.find_by(shortcode: shortcode)
        return render_not_found_response('party') unless party

        eager = PartyDifficulty::Calculator.eager_load_party(party.id)
        result = PartyDifficulty::Calculator.new(eager).call

        render json: {
          shortcode: shortcode,
          scoreable: result.scoreable,
          score: result.score,
          tier: result.difficulty ? DifficultyBlueprint.render_as_hash(result.difficulty, view: :nested) : nil,
          breakdown: result.breakdown,
          ruleset_version: result.ruleset_version
        }
      end

      private

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
