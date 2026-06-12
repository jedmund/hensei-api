# frozen_string_literal: true

module Api
  module V1
    class StatusBlueprint < ApiBlueprint
      field(:name) { |status| { en: status.name_en, ja: status.name_jp } }

      fields :family, :level, :category, :icon
    end
  end
end
