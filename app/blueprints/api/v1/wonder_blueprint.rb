# frozen_string_literal: true

module Api
  module V1
    ##
    # A catalogue Wonder with its effects, per-level bonuses and evolution
    # caps, for GET /wonders. JA text falls back to EN where the game text
    # isn't known yet.
    class WonderBlueprint < ApiBlueprint
      fields :granblue_id, :kind, :element, :max_level, :max_evolution, :battle_relevant,
             :hidden_in_unite_and_fight, :sort_order

      field :category_id, &:wonder_category_id

      field :name do |wonder|
        { en: wonder.name_en, ja: wonder.name_jp.presence || wonder.name_en }
      end

      field :description do |wonder|
        { en: wonder.description_en, ja: wonder.description_jp.presence || wonder.description_en }
      end

      field :effects do |wonder|
        wonder.wonder_effect_links.map do |link|
          effect = link.wonder_effect
          {
            action_id: effect.action_id,
            position: link.position,
            text: { en: effect.text_en, ja: effect.text_jp.presence || effect.text_en }
          }
        end
      end

      field :level_bonuses do |wonder|
        wonder.level_bonuses.map { |row| { level: row.level, stat: row.stat, value: row.value } }
      end

      field :evolution_caps do |wonder|
        wonder.evolution_caps.map { |row| { evolution: row.evolution, max_level: row.max_level } }
      end
    end
  end
end
