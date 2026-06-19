# frozen_string_literal: true

module Api
  module V1
    class DifficultyRuleBlueprint < ApiBlueprint
      fields :name, :description, :component, :rule_type, :params, :weight, :active,
             :created_at, :updated_at

      field :pending do |obj|
        obj.respond_to?(:pending?) && obj.pending?
      end
      field :pending_operation do |obj|
        obj.respond_to?(:pending_operation) ? obj.pending_operation : nil
      end
      field :draft_id do |obj|
        obj.respond_to?(:draft_id) ? obj.draft_id : nil
      end

      view :nested do
        fields :name, :component, :rule_type, :weight, :active
      end
    end
  end
end
