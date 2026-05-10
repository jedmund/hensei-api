# frozen_string_literal: true

module Api
  module V1
    class DifficultyRulesController < Api::V1::ApiController
      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role

      def index
        rules = DifficultyRule.order(:component, :name)
        rules = rules.where(component: params[:component]) if params[:component].present?
        rules = rules.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
        render json: DifficultyRuleBlueprint.render(rules)
      end

      def show
        rule = DifficultyRule.find_by(id: params[:id])
        return render_not_found_response('difficulty_rule') unless rule

        render json: DifficultyRuleBlueprint.render(rule)
      end

      def create
        rule = DifficultyRule.new(rule_params)
        rule.component ||= PartyDifficulty::Rules.component_for(rule.rule_type)
        if rule.save
          render json: DifficultyRuleBlueprint.render(rule), status: :created
        else
          render_validation_error_response(rule)
        end
      end

      def update
        rule = DifficultyRule.find_by(id: params[:id])
        return render_not_found_response('difficulty_rule') unless rule

        if rule.update(rule_params)
          render json: DifficultyRuleBlueprint.render(rule)
        else
          render_validation_error_response(rule)
        end
      end

      def destroy
        rule = DifficultyRule.find_by(id: params[:id])
        return render_not_found_response('difficulty_rule') unless rule

        rule.destroy
        head :no_content
      end

      def types
        render json: {
          types: PartyDifficulty::Rules.registered_types,
          grouped: PartyDifficulty::Rules.types_grouped_by_component
        }
      end

      private

      def rule_params
        permitted = params.require(:difficulty_rule).permit(:name, :description, :component, :rule_type,
                                                            :weight, :active, params: {})
        raw_params = params.require(:difficulty_rule)[:params]
        permitted[:params] = raw_params.to_unsafe_h if raw_params.is_a?(ActionController::Parameters)
        permitted
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
