# frozen_string_literal: true

module Api
  module V1
    class WeaponSkillBoostTypeBlueprint < ApiBlueprint
      field :name do |bt|
        {
          en: bt.name_en,
          ja: bt.name_jp
        }
      end

      fields :key, :category, :stacking_rule, :cap_is_flat, :notes

      field :grid_cap do |bt|
        bt.grid_cap&.to_f
      end
    end
  end
end
