# frozen_string_literal: true

module Api
  module V1
    class CharacterBlueprint < ApiBlueprint
      field :name do |c|
        {
          en: c.name_en,
          ja: c.name_jp
        }
      end

      fields :granblue_id, :character_id, :rarity,
             :element, :gender, :special, :season,
             :series, :gacha_available

      field :season_name do |c|
        c.season_name
      end

      field :series_names do |c|
        c.series_names
      end

      field :uncap do |c|
        {
          flb: c.flb,
          ulb: c.ulb
        }
      end

      field :race do |c|
        [c.race1, c.race2].compact
      end

      field :proficiency do |c|
        [c.proficiency1, c.proficiency2].compact
      end

      view :full do
        include_view :stats
        include_view :rates
        include_view :dates

        field :awakenings do
          Character::AWAKENINGS.map do |awakening|
            AwakeningBlueprint.render_as_hash(OpenStruct.new(awakening))
          end
        end

        field :nicknames do |c|
          {
            en: c.nicknames_en,
            ja: c.nicknames_jp
          }
        end

        field :links do |c|
          {
            wiki_en: c.wiki_en,
            wiki_ja: c.wiki_ja,
            gamewith: c.gamewith,
            kamigame: c.kamigame
          }
        end
      end

      # Separate view for raw data - only used by dedicated endpoint
      view :raw do
        excludes :name, :granblue_id, :character_id, :rarity, :element, :gender, :special, :uncap, :race, :proficiency

        field :wiki_raw do |c|
          c.wiki_raw
        end

        field :game_raw_en do |c|
          c.game_raw_en
        end

        field :game_raw_jp do |c|
          c.game_raw_jp
        end
      end

      view :stats do
        field :hp do |c|
          {
            min_hp: c.min_hp,
            max_hp: c.max_hp,
            max_hp_flb: c.max_hp_flb
          }
        end

        field :atk do |c|
          {
            min_atk: c.min_atk,
            max_atk: c.max_atk,
            max_atk_flb: c.max_atk_flb
          }
        end
      end

      view :rates do
        fields :base_da, :base_ta

        field :ougi_ratio do |c|
          {
            ougi_ratio: c.ougi_ratio,
            ougi_ratio_flb: c.ougi_ratio_flb
          }
        end
      end

      view :dates do
        field :release_date
        field :flb_date
        field :ulb_date
      end
    end
  end
end
