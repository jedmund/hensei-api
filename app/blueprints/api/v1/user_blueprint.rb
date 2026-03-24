# frozen_string_literal: true

module Api
  module V1
    class UserBlueprint < ApiBlueprint
      # Lightweight view for embedding in party responses — just enough for avatar + link
      view :inline do
        fields :username, :display_name, :gender, :youtube
        field :avatar do |user|
          {
            picture: user.picture,
            element: user.element
          }
        end
      end

      view :minimal do
        fields :username, :display_name, :language, :private, :gender, :theme, :role, :granblue_id, :show_gamertag, :wiki_profile, :youtube
        # Return collection_privacy as integer (enum returns string by default)
        field :collection_privacy do |user|
          User.collection_privacies[user.collection_privacy]
        end
        field :avatar do |user|
          {
            picture: user.picture,
            element: user.element
          }
        end
        # Use preloaded active_crew_membership to avoid N+1
        field :gamertag, if: ->(_, user, _) {
          user.show_gamertag && user.active_crew_membership&.crew&.gamertag.present?
        } do |user|
          user.active_crew_membership.crew.gamertag
        end
        field :crew_name, if: ->(_, user, _) {
          user.show_gamertag && user.active_crew_membership&.crew&.name.present?
        } do |user|
          user.active_crew_membership.crew.name
        end
      end

      view :profile do
        include_view :minimal

        field :parties, if: ->(_fn, _obj, options) { options[:parties].length.positive? } do |_, options|
          PartyBlueprint.render_as_hash(options[:parties], view: :list)
        end
      end

      view :token do
        fields :username, :display_name, :token, :email_verified
      end

      # Settings view includes all user data + email (only for authenticated user viewing own settings)
      view :settings do
        include_view :minimal
        fields :email, :email_verified, :import_weapons, :default_import_visibility
        field :has_stored_edit_keys do |user|
          user.user_edit_keys.any?
        end
      end
    end
  end
end
