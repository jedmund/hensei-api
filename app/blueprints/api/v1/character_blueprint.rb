# frozen_string_literal: true

module Api
  module V1
    class CharacterBlueprint < ApiBlueprint
      field :name do |w|
        {
          en: w.name_en,
          ja: w.name_jp
        }
      end

      fields :granblue_id, :character_id, :rarity,
             :element, :gender, :special

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
          max_hp_flb: w.max_hp_flb
        }
      end

      field :atk do |w|
        {
          min_atk: w.min_atk,
          max_atk: w.max_atk,
          max_atk_flb: w.max_atk_flb
        }
      end

      field :race do |w|
        [
          w.race1,
          w.race2
        ]
      end

      field :proficiency do |w|
        [
          w.proficiency1,
          w.proficiency2
        ]
      end

      field :data do |w|
        {
          base_da: w.base_da,
          base_ta: w.base_ta
        }
      end

      field :ougi_ratio do |w|
        {
          ougi_ratio: w.ougi_ratio,
          ougi_ratio_flb: w.ougi_ratio_flb
        }
      end

      field :awakenings do
        Awakening.where(object_type: 'Character').map do |a|
          AwakeningBlueprint.render_as_hash(a)
        end
      end
    end
  end
end
