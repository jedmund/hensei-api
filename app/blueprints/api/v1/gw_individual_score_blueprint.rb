# frozen_string_literal: true

module Api
  module V1
    class GwIndividualScoreBlueprint < ApiBlueprint
      fields :round, :score, :is_cumulative

      field :player_name do |score|
        score.player_name
      end

      field :player_type do |score|
        if score.crew_membership_id.present?
          'member'
        elsif score.phantom_player_id.present?
          'phantom'
        end
      end

      view :with_member do
        field :member do |score|
          if score.crew_membership.present?
            CrewMembershipBlueprint.render_as_hash(score.crew_membership, view: :with_user)
          end
        end

        field :phantom do |score|
          if score.phantom_player.present?
            PhantomPlayerBlueprint.render_as_hash(score.phantom_player)
          end
        end
      end
    end
  end
end
