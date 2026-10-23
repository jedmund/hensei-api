# frozen_string_literal: true

module Api
  module V1
    class StatusBlueprint < ApiBlueprint
      field(:name) { |status| { en: status.name_en, ja: status.name_jp } }

      # qualifier: tells apart two statuses that show the same name ("Turns", "Times"); null for most.
      fields :qualifier, :family, :level, :category, :icon

      # What the status does, from the gbf.wiki status list (English).
      field :description
    end
  end
end
