# frozen_string_literal: true

module Api
  module V1
    class CrewBlueprint < ApiBlueprint
      fields :name, :gamertag, :granblue_crew_id, :description, :created_at

      view :minimal do
        fields :name, :gamertag
      end

      view :full do
        fields :name, :gamertag, :granblue_crew_id, :description, :created_at

        field :member_count do |crew|
          crew.active_memberships.count
        end

        field :captain do |crew|
          captain = crew.captain
          UserBlueprint.render_as_hash(captain, view: :minimal) if captain
        end

        field :vice_captains do |crew|
          UserBlueprint.render_as_hash(crew.vice_captains, view: :minimal)
        end
      end

      view :with_members do
        include_view :full

        field :members do |crew|
          CrewMembershipBlueprint.render_as_hash(
            crew.active_memberships.includes(:user).order(role: :desc, created_at: :asc),
            view: :with_user
          )
        end
      end
    end
  end
end
