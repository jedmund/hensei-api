# frozen_string_literal: true

module Api
  module V1
    class DifficultyRulesController < Api::V1::ApiController
      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role

      def index
        rules = if with_drafts?
                  PartyDifficulty::DraftWorkspace.for(current_user).merged_rules
                else
                  DifficultyRule.order(:component, :name)
                end

        if params[:component].present?
          rules = rules.respond_to?(:where) ? rules.where(component: params[:component]) : rules.select { |r| r.component == params[:component] }
        end

        if params.key?(:active)
          active = ActiveModel::Type::Boolean.new.cast(params[:active])
          rules = rules.respond_to?(:where) ? rules.where(active: active) : rules.select { |r| r.active == active }
        end

        render json: DifficultyRuleBlueprint.render(rules)
      end

      def show
        rule = DifficultyRule.find_by(id: params[:id])
        return render_not_found_response('difficulty_rule') unless rule

        render json: DifficultyRuleBlueprint.render(rule)
      end

      def create
        attrs = rule_params.to_h
        attrs[:component] ||= PartyDifficulty::Rules.component_for(attrs[:rule_type])

        draft = PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'DifficultyRule', target_id: nil, operation: 'create', attributes: attrs
        )
        render json: draft_envelope(draft), status: :created
      end

      def update
        rule = DifficultyRule.find_by(id: params[:id])
        return render_not_found_response('difficulty_rule') unless rule

        draft = PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'DifficultyRule', target_id: rule.id, operation: 'update', attributes: rule_params
        )
        render json: draft_envelope(draft)
      end

      def destroy
        rule = DifficultyRule.find_by(id: params[:id])
        return render_not_found_response('difficulty_rule') unless rule

        PartyDifficulty::DraftWorkspace.for(current_user).stage!(
          target_type: 'DifficultyRule', target_id: rule.id, operation: 'destroy', attributes: {}
        )
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

      def with_drafts?
        return false unless current_user&.role && current_user.role >= 7

        ActiveModel::Type::Boolean.new.cast(params[:with_drafts])
      end

      def draft_envelope(draft)
        {
          draft: {
            id: draft.id,
            target_type: draft.target_type,
            target_id: draft.target_id,
            operation: draft.operation,
            attributes: draft.attributes_payload
          }
        }
      end
    end
  end
end
