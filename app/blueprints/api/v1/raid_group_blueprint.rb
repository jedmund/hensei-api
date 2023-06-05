# frozen_string_literal: true

module Api
  module V1
    class RaidGroupBlueprint < ApiBlueprint
      field :name do |group|
        {
          en: group.name_en,
          ja: group.name_jp
        }
      end

      fields :difficulty, :order, :section, :extra, :hl

      association :raids, blueprint: RaidBlueprint, view: :nested
    end
  end
end
