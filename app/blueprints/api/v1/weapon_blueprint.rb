# frozen_string_literal: true

module Api
  module V1
    class WeaponBlueprint < ApiBlueprint
      field :name do |w|
        {
          en: w.name_en,
          ja: w.name_jp
        }
      end

      # Primary information
      fields :granblue_id, :element, :proficiency,
             :max_level, :max_skill_level, :max_awakening_level, :limit, :rarity,
             :series, :ax, :ax_type

      # Uncap information
      field :uncap do |w|
        {
          flb: w.flb,
          ulb: w.ulb,
          transcendence: w.transcendence
        }
      end

      view :stats do
        field :hp do |w|
          {
            min_hp: w.min_hp,
            max_hp: w.max_hp,
            max_hp_flb: w.max_hp_flb,
            max_hp_ulb: w.max_hp_ulb
          }
        end

        field :atk do |w|
          {
            min_atk: w.min_atk,
            max_atk: w.max_atk,
            max_atk_flb: w.max_atk_flb,
            max_atk_ulb: w.max_atk_ulb
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
        association :awakenings,
                    blueprint: AwakeningBlueprint,
                    if: ->(_field_name, weapon, _options) { weapon.awakenings.any? }

        field :nicknames do |w|
          {
            en: w.nicknames_en,
            ja: w.nicknames_jp
          }
        end

        field :links do |w|
          {
            wiki_en: w.wiki_en,
            wiki_ja: w.wiki_ja,
            gamewith: w.gamewith,
            kamigame: w.kamigame
          }
        end

        field :recruits do |w|
          next nil unless w.recruits.present?

          character = Character.find_by(granblue_id: w.recruits)
          next nil unless character

          {
            id: character.id,
            granblue_id: character.granblue_id,
            name: {
              en: character.name_en,
              ja: character.name_jp
            }
          }
        end
      end

      # Separate view for raw data - only used by dedicated endpoint
      view :raw do
        excludes :name, :granblue_id, :element, :proficiency, :max_level, :max_skill_level,
                 :max_awakening_level, :limit, :rarity, :series, :ax, :ax_type, :uncap

        field :wiki_raw do |w|
          w.wiki_raw
        end

        field :game_raw_en do |w|
          w.game_raw_en
        end

        field :game_raw_jp do |w|
          w.game_raw_jp
        end
      end
    end
  end
end
