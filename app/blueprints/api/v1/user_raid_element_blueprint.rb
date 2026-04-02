# frozen_string_literal: true

module Api
  module V1
    class UserRaidElementBlueprint < ApiBlueprint
      field :raid_id
      field :element

      field :raid_name do |ure|
        {
          en: ure.raid.name_en,
          ja: ure.raid.name_jp
        }
      end
    end
  end
end
