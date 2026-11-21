# frozen_string_literal: true

module Api
  module V1
    # A Wonder a user owns; a party Wonder plus the in-game Active toggle.
    class CollectionWonderBlueprint < PartyWonderBlueprint
      field :active
    end
  end
end
