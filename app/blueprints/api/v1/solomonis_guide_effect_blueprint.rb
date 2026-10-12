# frozen_string_literal: true

module Api
  module V1
    # An Evoking Solomonis guidebook effect (catalogue entry). Names may hold a
    # `{value}` placeholder that a run's display_value fills in.
    class SolomonisGuideEffectBlueprint < ApiBlueprint
      fields :granblue_id, :rarity, :stackable, :icon_category, :icon_type,
             :target_type, :target_values, :character_id,
             :availability, :type_tags, :effect_tags

      field :name do |effect|
        { en: effect.name_en, ja: effect.name_jp }
      end
    end
  end
end
