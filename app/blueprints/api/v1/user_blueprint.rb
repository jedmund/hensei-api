# frozen_string_literal: true

module Api
  module V1
    class UserBlueprint < ApiBlueprint
      view :minimal do
        fields :username, :language, :private, :gender, :theme, :role, :granblue_id, :show_gamertag
        field :avatar do |user|
          {
            picture: user.picture,
            element: user.element
          }
        end
        field :gamertag, if: ->(_, user, _) { user.show_gamertag && user.crew&.gamertag.present? } do |user|
          user.crew.gamertag
        end
      end

      view :profile do
        include_view :minimal

        field :parties, if: ->(_fn, _obj, options) { options[:parties].length.positive? } do |_, options|
          PartyBlueprint.render_as_hash(options[:parties], view: :preview)
        end
      end

      view :token do
        fields :username, :token
      end

      view :settings do
        fields :email, :show_gamertag
      end
    end
  end
end
