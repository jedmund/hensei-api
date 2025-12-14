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

      fields :granblue_id, :rarity

      # Return proficiency as integer (nil for quirk artifacts)
      field :proficiency do |a|
        a.proficiency_before_type_cast
      end

      field :release_date, if: ->(_field, a, _options) { a.release_date.present? }
    end
  end
end
