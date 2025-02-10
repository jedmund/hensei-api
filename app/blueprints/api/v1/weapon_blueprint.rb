# frozen_string_literal: true

module Api
  module V1
    class WeaponBlueprint < ApiBlueprint
      field :name do |w|
        {
          en: w.name_en,
          ja: w.name_jp
        }
      end

      # Primary information
      fields :granblue_id, :element, :proficiency,
             :max_level, :max_skill_level, :max_awakening_level, :limit, :rarity,
             :series, :ax, :ax_type

      # Uncap information
      field :uncap do |w|
        {
          flb: w.flb,
          ulb: w.ulb,
          transcendence: w.transcendence
        }
      end

      view :stats do
        field :hp do |w|
          {
            min_hp: w.min_hp,
            max_hp: w.max_hp,
            max_hp_flb: w.max_hp_flb,
            max_hp_ulb: w.max_hp_ulb
          }
        end

        field :atk do |w|
          {
            min_atk: w.min_atk,
            max_atk: w.max_atk,
            max_atk_flb: w.max_atk_flb,
            max_atk_ulb: w.max_atk_ulb
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
        association :awakenings,
                    blueprint: AwakeningBlueprint,
                    if: ->(_field_name, weapon, _options) { weapon.awakenings.any? }
      end
    end
  end
end
