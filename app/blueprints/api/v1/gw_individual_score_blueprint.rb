# frozen_string_literal: true

module Api
  module V1
    class GwIndividualScoreBlueprint < ApiBlueprint
      fields :round, :score, :is_cumulative

      view :with_member do
        field :member do |score|
          if score.crew_membership.present?
            CrewMembershipBlueprint.render_as_hash(score.crew_membership, view: :with_user)
          end
        end
      end
    end
  end
end
