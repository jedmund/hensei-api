# frozen_string_literal: true

module Api
  module V1
    class DifficultyComponentBlueprint < ApiBlueprint
      fields :name, :weight, :enabled, :min_count_to_score, :target_max,
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
    end
  end
end
