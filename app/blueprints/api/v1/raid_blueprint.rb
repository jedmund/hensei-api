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

        fields :slug, :level, :element, :player_count, :enemy_id, :summon_id, :quest_id, :released_at

        # For places that already show the group (Home's tabs, the raid picker);
        # null when the raid has none, so its name is used
        field :short_name do |raid|
          next nil if raid.short_name_en.blank? && raid.short_name_jp.blank?

          { en: raid.short_name_en, ja: raid.short_name_jp }
        end

        field :extra do |raid|
          raid.effective_extra
        end

        association :group, blueprint: RaidGroupBlueprint, view: :flat
      end

      # Minimal view for party list cards
      view :list do
        identifier :id
        # Home's raid thumbnails and "see all" filters key off the slug
        field :slug

        field :name do |raid|
          {
            en: raid.name_en,
            ja: raid.name_jp
          }
        end

        # For places that already show the group (Home's tabs, the raid picker);
        # null when the raid has none, so its name is used
        field :short_name do |raid|
          next nil if raid.short_name_en.blank? && raid.short_name_jp.blank?

          { en: raid.short_name_en, ja: raid.short_name_jp }
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
