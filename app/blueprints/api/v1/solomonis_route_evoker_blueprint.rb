# frozen_string_literal: true

module Api
  module V1
    # A route-eligible Evoker (a Character with a Solomonis zone). The default
    # view is the reference on a party; :catalogue adds the zone.
    class SolomonisRouteEvokerBlueprint < ApiBlueprint
      fields :granblue_id, :element

      field :name do |character|
        { en: character.name_en, ja: character.name_jp }
      end

      view :catalogue do
        field :zone do |character|
          SolomonisRouteEvokerBlueprint.zone_hash(character.solomonis_zone)
        end
      end

      def self.zone_hash(raid)
        return nil unless raid

        { id: raid.id, slug: raid.slug, name: { en: raid.name_en, ja: raid.name_jp } }
      end
    end
  end
end
