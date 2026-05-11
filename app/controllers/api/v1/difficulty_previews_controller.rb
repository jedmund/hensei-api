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

        # TODO(party-difficulty-perf): cache DifficultyRule.active /
        # DifficultyComponent.all / Difficulty.ordered by DifficultyConfig
        # current_version inside Calculator#initialize. See
        # docs/follow-ups/party-difficulty.md.
        eager = PartyDifficulty::Calculator.eager_load_party(party.id)
        result = PartyDifficulty::Calculator.new(eager, **calculator_overrides).call

        render json: {
          shortcode: shortcode,
          scoreable: result.scoreable,
          score: result.score,
          tier: result.difficulty ? DifficultyBlueprint.render_as_hash(result.difficulty, view: :nested) : nil,
          breakdown: result.breakdown,
          ruleset_version: result.ruleset_version,
          with_drafts: applying_drafts?
        }
      end

      private

      def calculator_overrides
        return {} unless applying_drafts?

        ws = PartyDifficulty::DraftWorkspace.for(current_user)
        {
          rules: ws.merged_rules(only_active: true),
          components: ws.merged_components,
          difficulties: ws.merged_tiers
        }
      end

      def applying_drafts?
        return false unless current_user&.role && current_user.role >= 7
        return false if params.key?(:with_drafts) && !ActiveModel::Type::Boolean.new.cast(params[:with_drafts])

        PartyDifficulty::DraftWorkspace.for(current_user).pending_count.positive?
      end
    end
  end
end
