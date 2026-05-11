# frozen_string_literal: true

module Api
  module V1
    class DifficultyComponentBlueprint < ApiBlueprint
      fields :name, :weight, :enabled, :min_count_to_score, :target_max,
             :created_at, :updated_at
    end
  end
end
