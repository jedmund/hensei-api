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
             :max_level, :max_skill_level, :max_awakening_level, :limit, :rarity,
             :series, :ax, :ax_type

      field :uncap do |w|
        {
          flb: w.flb,
          ulb: w.ulb
        }
      end

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

      field :awakenings, if: ->(_field_name, w, _options) { w.awakenings } do |w|
        w.awakenings.map do |a|
          AwakeningBlueprint.render_as_hash(a)
        end
      end
    end
  end
end
