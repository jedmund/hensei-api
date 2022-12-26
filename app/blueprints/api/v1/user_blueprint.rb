# frozen_string_literal: true

module Api
  module V1
    class UserBlueprint < ApiBlueprint
      view :minimal do
        fields :username, :language, :private, :gender, :theme
        field :avatar do |user|
          {
            picture: user.picture,
            element: user.element
          }
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
        fields :email
      end
    end
  end
end
