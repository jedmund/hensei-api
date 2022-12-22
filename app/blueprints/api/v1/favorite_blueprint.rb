# frozen_string_literal: true

module Api
  module V1
    class FavoriteBlueprint < ApiBlueprint
      association :user,
                  name: :user,
                  blueprint: UserBlueprint,
                  view: :minimal

      association :party,
                  name: :party,
                  blueprint: PartyBlueprint,
                  view: :preview

      fields :created_at, :updated_at

      view :destroyed do
        field :destroyed do
          true
        end
      end
    end
  end
end
