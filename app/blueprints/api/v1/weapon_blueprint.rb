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

      fields :granblue_id, :element, :proficiency,
             :limit, :rarity, :series

      field :ax do |w|
        {
          has_ax: w.ax,
          type: w.ax_type
        }
      end

      field :awakening do |w|
        {
          has_awakening: w.awakening,
          types: w.awakening_types
        }
      end

      field :uncap do |w|
        {
          flb: w.flb,
          ulb: w.ulb
        }
      end

      field :stats do |w|
        {
          atk: {
            min_atk: w.min_atk,
            max_atk: w.max_atk,
            max_atk_flb: w.max_atk_flb,
            max_atk_ulb: w.max_atk_ulb
          },
          hp: {
            min_hp: w.min_hp,
            max_hp: w.max_hp,
            max_hp_flb: w.max_hp_flb,
            max_hp_ulb: w.max_hp_ulb
          },
          max_level: w.max_level,
          max_skill_level: w.max_skill_level
        }
      end
    end
  end
end
