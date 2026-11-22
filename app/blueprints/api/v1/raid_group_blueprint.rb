# frozen_string_literal: true

module Api
  module V1
    class RaidGroupBlueprint < ApiBlueprint
      view :flat do
        identifier :id

        field :name do |group|
          {
            en: group.name_en,
            ja: group.name_jp
          }
        end

        fields :difficulty, :order, :section, :extra, :guidebooks, :hl, :unlimited, :content_mode, :support_summon
      end

      # Minimal view for party list cards
      view :list do
        # section: cards show clear time and button counts on Event teams only
        fields :unlimited, :content_mode, :section
      end

      view :full do
        include_view :flat
        association :raids, blueprint: RaidBlueprint, view: :nested
      end
    end
  end
end
