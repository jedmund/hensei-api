# frozen_string_literal: true

module Api
  module V1
    class SummonBlueprint < ApiBlueprint
      field :name do |s|
        {
          en: s.name_en,
          ja: s.name_jp
        }
      end

      fields :granblue_id, :element, :rarity, :max_level, :subaura, :limit, :promotions

      field :promotion_names do |s|
        s.promotion_names
      end

      field :series do |s|
        if s.summon_series.present?
          {
            id: s.summon_series_id,
            slug: s.summon_series.slug,
            name: {
              en: s.summon_series.name_en,
              ja: s.summon_series.name_jp
            }
          }
        end
      end

      field :uncap do |s|
        {
          flb: s.flb,
          ulb: s.ulb,
          transcendence: s.transcendence
        }
      end

      view :preview do
        excludes :name, :element, :rarity, :max_level, :promotions,
                 :promotion_names, :series, :uncap
      end

      # Minimal view for party list cards — just enough for image rendering
      view :list do
        excludes :name, :element, :rarity, :max_level, :promotions,
                 :promotion_names, :series, :uncap, :subaura, :limit
      end

      view :stats do
        field :hp do |s|
          {
            min_hp: s.min_hp,
            max_hp: s.max_hp,
            max_hp_flb: s.max_hp_flb,
            max_hp_ulb: s.max_hp_ulb,
            max_hp_xlb: s.max_hp_xlb
          }
        end

        field :atk do |s|
          {
            min_atk: s.min_atk,
            max_atk: s.max_atk,
            max_atk_flb: s.max_atk_flb,
            max_atk_ulb: s.max_atk_ulb,
            max_atk_xlb: s.max_atk_xlb
          }
        end
      end

      view :dates do
        field :release_date
        field :flb_date
        field :ulb_date
        field :transcendence_date
      end

      view :full do
        include_view :stats
        include_view :dates

        field :nicknames do |s|
          {
            en: s.nicknames_en,
            ja: s.nicknames_jp
          }
        end

        field :wiki do |s|
          {
            en: s.wiki_en,
            ja: s.wiki_ja
          }
        end

        fields :gamewith, :kamigame
      end

      # Separate view for raw data - only used by dedicated endpoint
      view :raw do
        excludes :name, :granblue_id, :element, :rarity, :max_level, :uncap

        field :wiki_raw do |s|
          s.wiki_raw
        end

        field :game_raw_en do |s|
          s.game_raw_en
        end

        field :game_raw_jp do |s|
          s.game_raw_jp
        end
      end
    end
  end
end
