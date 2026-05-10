# frozen_string_literal: true

module Api
  module V1
    class DifficultyRuleBlueprint < ApiBlueprint
      fields :name, :description, :component, :rule_type, :params, :weight, :active,
             :created_at, :updated_at

      view :nested do
        fields :name, :component, :rule_type, :weight, :active
      end
    end
  end
end
