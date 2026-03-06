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
             :element, :gender, :special, :season

      field :season_name do |c|
        c.season_name
      end

      field :series do |c|
        # Use new lookup table if available
        if c.character_series_records.any?
          c.character_series_records.ordered.map do |cs|
            {
              id: cs.id,
              slug: cs.slug,
              name: {
                en: cs.name_en,
                ja: cs.name_jp
              }
            }
          end
        else
          # Legacy fallback - return integer array
          c.series
        end
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

      view :preview do
        excludes :name, :character_id, :rarity, :element, :gender, :special, :season,
                 :season_name, :series, :series_names, :uncap, :race, :proficiency
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

        field :wiki do |c|
          {
            en: c.wiki_en,
            ja: c.wiki_ja
          }
        end

        fields :gamewith, :kamigame
      end

      # Separate view for recruitment info - only include when needed (e.g., character detail page)
      view :with_recruitment do
        include_view :full

        field :recruited_by do |c|
          weapon = Weapon.find_by(recruits: c.granblue_id)
          next nil unless weapon

          {
            id: weapon.id,
            granblue_id: weapon.granblue_id,
            name: {
              en: weapon.name_en,
              ja: weapon.name_jp
            },
            promotions: weapon.promotions,
            promotion_names: weapon.promotion_names
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
