# frozen_string_literal: true

module Api
  module V1
    class ArtifactSkillBlueprint < ApiBlueprint
      field :name do |s|
        {
          en: s.name_en,
          ja: s.name_jp
        }
      end

      field :game_name do |s|
        {
          en: s.game_name_en,
          ja: s.game_name_jp
        }
      end

      fields :skill_group, :modifier, :polarity, :score_category

      field :base_values do |s|
        s.base_values
      end

      field :growth, if: ->(_field, s, _options) { s.growth.present? } do |s|
        s.growth.to_f
      end

      field :suffix do |s|
        {
          en: s.suffix_en,
          ja: s.suffix_jp
        }
      end
    end
  end
end
