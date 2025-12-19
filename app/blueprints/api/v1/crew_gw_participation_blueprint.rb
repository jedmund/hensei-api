# frozen_string_literal: true

module Api
  module V1
    class CrewGwParticipationBlueprint < ApiBlueprint
      fields :preliminary_ranking, :final_ranking

      field :total_score do |participation|
        participation.total_individual_honors
      end

      field :wins do |participation|
        participation.wins_count
      end

      field :losses do |participation|
        participation.losses_count
      end

      view :summary do
        # summary uses base fields only (no gw_event)
      end

      view :with_event do
        field :gw_event do |participation|
          GwEventBlueprint.render_as_hash(participation.gw_event)
        end
      end

      view :with_crew do
        field :crew do |participation|
          CrewBlueprint.render_as_hash(participation.crew, view: :minimal)
        end
        field :gw_event do |participation|
          GwEventBlueprint.render_as_hash(participation.gw_event)
        end
      end

      view :full do
        field :gw_event do |participation|
          GwEventBlueprint.render_as_hash(participation.gw_event)
        end
        field :crew_scores do |participation|
          GwCrewScoreBlueprint.render_as_hash(participation.gw_crew_scores.order(:round))
        end
      end

      view :with_individual_scores do
        field :gw_event do |participation|
          GwEventBlueprint.render_as_hash(participation.gw_event)
        end
        field :crew_scores do |participation|
          GwCrewScoreBlueprint.render_as_hash(participation.gw_crew_scores.order(:round))
        end
        field :individual_scores do |participation, options|
          GwIndividualScoreBlueprint.render_as_hash(
            participation.gw_individual_scores.includes(:crew_membership).order(:round),
            view: :with_member,
            current_user: options[:current_user]
          )
        end
      end
    end
  end
end
