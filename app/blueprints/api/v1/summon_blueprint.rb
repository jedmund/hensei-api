# frozen_string_literal: true

module Api
  module V1
    class SummonBlueprint < ApiBlueprint
      field :name do |s|
        {
          en: s.name_en,
          ja: s.name_jp
        }
      end

      fields :granblue_id, :element, :rarity, :max_level

      field :uncap do |s|
        {
          flb: s.flb,
          ulb: s.ulb,
          transcendence: s.transcendence
        }
      end

      view :stats do
        field :hp do |s|
          {
            min_hp: s.min_hp,
            max_hp: s.max_hp,
            max_hp_flb: s.max_hp_flb,
            max_hp_ulb: s.max_hp_ulb,
            max_hp_xlb: s.max_hp_xlb
          }
        end

        field :atk do |s|
          {
            min_atk: s.min_atk,
            max_atk: s.max_atk,
            max_atk_flb: s.max_atk_flb,
            max_atk_ulb: s.max_atk_ulb,
            max_atk_xlb: s.max_atk_xlb
          }
        end
      end

      view :dates do
        field :release_date
        field :flb_date
        field :ulb_date
        field :transcendence_date
      end

      view :full do
        include_view :stats
        include_view :dates
      end
    end
  end
end
