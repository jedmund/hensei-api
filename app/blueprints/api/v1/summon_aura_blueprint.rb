# frozen_string_literal: true

module Api
  module V1
    class SummonAuraBlueprint < ApiBlueprint
      fields :slot, :target, :element, :uncap_level, :transcendence_stage, :condition

      field :value do |aura|
        aura.value&.to_f
      end

      field :description do |aura|
        {
          en: aura.description_en,
          ja: aura.description_jp
        }
      end
    end
  end
end
