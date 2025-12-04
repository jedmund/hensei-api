# frozen_string_literal: true

module Api
  module V1
    class GwCrewScoreBlueprint < ApiBlueprint
      fields :round, :crew_score, :opponent_score, :opponent_name, :opponent_granblue_id, :victory
    end
  end
end
