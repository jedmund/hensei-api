# frozen_string_literal: true

module Api
  module V1
    class ArtifactBlueprint < ApiBlueprint
      field :name do |a|
        {
          en: a.name_en,
          ja: a.name_jp
        }
      end

      fields :granblue_id, :proficiency, :rarity

      field :release_date, if: ->(_field, a, _options) { a.release_date.present? }
    end
  end
end
