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

      # Display text: the English wikitext rendered by WeaponSkills::WikiMarkup (bold,
      # tooltips, line breaks), and the Japanese text as the build wrote it (already plain).
      field :description_segments do |aura|
        {
          en: WeaponSkills::WikiMarkup.segments(aura.description_en),
          ja: aura.description_jp.present? ? [{ text: aura.description_jp }] : []
        }
      end
    end
  end
end
