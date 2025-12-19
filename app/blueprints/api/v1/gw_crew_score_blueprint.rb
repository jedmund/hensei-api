# frozen_string_literal: true

module Api
  module V1
    class GwCrewScoreBlueprint < ApiBlueprint
      fields :crew_score, :opponent_score, :opponent_name, :opponent_granblue_id, :victory

      # Return round as integer value instead of enum string
      field :round do |score|
        GwCrewScore.rounds[score.round]
      end
    end
  end
end
