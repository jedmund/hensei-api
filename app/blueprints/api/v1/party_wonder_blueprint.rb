# frozen_string_literal: true

module Api
  module V1
    ##
    # A Wonder on a team: the catalogue id and game id, its level, evolution
    # and character count, the image to show and the computed bonuses.
    # CollectionWonderBlueprint adds the Active flag.
    class PartyWonderBlueprint < ApiBlueprint
      fields :wonder_id, :level, :evolution, :possession

      field(:granblue_id) { |holding| holding.wonder.granblue_id }
      field :image, &:image_name
      field :bonuses, &:bonuses
    end
  end
end
