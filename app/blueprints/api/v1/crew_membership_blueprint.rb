# frozen_string_literal: true

module Api
  module V1
    class CrewMembershipBlueprint < ApiBlueprint
      fields :role, :retired, :retired_at, :joined_at, :created_at

      view :with_user do
        fields :role, :retired, :retired_at, :joined_at, :created_at

        field :user do |membership|
          UserBlueprint.render_as_hash(membership.user, view: :minimal)
        end
      end

      view :with_crew do
        fields :role, :retired, :retired_at, :joined_at, :created_at

        field :crew do |membership|
          CrewBlueprint.render_as_hash(membership.crew, view: :minimal)
        end
      end
    end
  end
end
