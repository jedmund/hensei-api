# frozen_string_literal: true

module Api
  module V1
    class GuidebookBlueprint < ApiBlueprint
      field :name do |book|
        {
          en: book.name_en,
          ja: book.name_jp
        }
      end

      field :description do |book|
        {
          en: book.name_en,
          ja: book.name_jp
        }
      end

      fields :granblue_id
    end
  end
end
