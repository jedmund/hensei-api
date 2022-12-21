# frozen_string_literal: true

module Api
  module V1
    class UserBlueprint < ApiBlueprint
      view :minimal do
        fields :username, :language, :private, :gender
        field :avatar do |user|
          {
            picture: user.picture,
            element: user.element
          }
        end
      end

      view :profile do
        association :parties,
                    name: :parties,
                    blueprint: PartyBlueprint, view: :preview,
                    if: ->(_field_name, user, _options) { user.parties.length.positive? },
                    &:parties
      end

      view :settings do
        fields :email
      end
    end
  end
end
