# frozen_string_literal: true

module Api
  module V1
    class SummonBlueprint < ApiBlueprint
      field :name do |w|
        {
          en: w.name_en,
          ja: w.name_jp
        }
      end

      fields :granblue_id, :element, :rarity, :max_level

      field :uncap do |w|
        {
          flb: w.flb,
          ulb: w.ulb,
          xlb: w.xlb
        }
      end

      field :hp do |w|
        {
          min_hp: w.min_hp,
          max_hp: w.max_hp,
          max_hp_flb: w.max_hp_flb,
          max_hp_ulb: w.max_hp_ulb,
          max_hp_xlb: w.max_hp_xlb
        }
      end

      field :atk do |w|
        {
          min_atk: w.min_atk,
          max_atk: w.max_atk,
          max_atk_flb: w.max_atk_flb,
          max_atk_ulb: w.max_atk_ulb,
          max_atk_xlb: w.max_atk_xlb
        }
      end
    end
  end
end
