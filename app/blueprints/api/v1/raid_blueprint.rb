# frozen_string_literal: true

module Api
  module V1
    class RaidBlueprint < ApiBlueprint
      view :nested do
        identifier :id

        field :name do |raid|
          {
            en: raid.name_en,
            ja: raid.name_jp
          }
        end

        fields :slug, :level, :element, :player_count, :enemy_id, :summon_id, :quest_id, :trackable

        field :extra do |raid|
          raid.effective_extra
        end

        association :group, blueprint: RaidGroupBlueprint, view: :flat
      end

      # Minimal view for party list cards
      view :list do
        identifier :id

        field :name do |raid|
          {
            en: raid.name_en,
            ja: raid.name_jp
          }
        end

        field :extra do |raid|
          raid.effective_extra
        end

        association :group, blueprint: RaidGroupBlueprint, view: :list
      end

      view :full do
        include_view :nested
      end
    end
  end
end
