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

      # Rule `params` is an unstructured jsonb whose shape varies per rule_type,
      # so strong-params can't enumerate keys generically — DifficultyRule's
      # params_valid_for_rule_type validator constrains the payload after assignment.
      # Reject non-hash params explicitly so callers get a 422 instead of having
      # the field silently dropped.
      def rule_params
        permitted = params.require(:difficulty_rule).permit(:name, :description, :component,
                                                            :rule_type, :weight, :active)
        raw = params.require(:difficulty_rule)[:params]

        case raw
        when nil
          permitted
        when ActionController::Parameters
          permitted[:params] = raw.to_unsafe_h
          permitted
        when Hash
          permitted[:params] = raw
          permitted
        else
          raise ActionController::BadRequest, 'difficulty_rule.params must be an object'
        end
      end
    end
  end
end
