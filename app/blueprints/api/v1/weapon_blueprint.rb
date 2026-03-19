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
             :max_level, :max_skill_level, :max_awakening_level, :max_exorcism_level,
             :limit, :rarity, :ax, :ax_type, :gacha, :promotions, :forge_order, :extra,
             :element_variant_ids

      # Series - returns full object with flags resolved through variant overrides
      field :series do |w|
        next nil unless w.weapon_series.present?

        {
          id: w.weapon_series_id,
          slug: w.weapon_series.slug,
          name: {
            en: w.weapon_series.name_en,
            ja: w.weapon_series.name_jp
          },
          has_weapon_keys: w.effective_has_weapon_keys,
          has_awakening: w.effective_has_awakening,
          augment_type: w.effective_augment_type,
          num_weapon_keys: w.effective_num_weapon_keys,
          extra: w.effective_extra,
          element_changeable: w.effective_element_changeable,
          weapon_series_variant_id: w.weapon_series_variant_id,
          weapon_series_variant_name: w.weapon_series_variant&.name
        }
      end

      field :promotion_names do |w|
        w.promotion_names
      end

      # Uncap information
      field :uncap do |w|
        {
          flb: w.flb,
          ulb: w.ulb,
          transcendence: w.transcendence,
          extra_prerequisite: w.extra_prerequisite
        }
      end

      view :preview do
        excludes :name, :proficiency, :max_level, :max_skill_level, :max_awakening_level,
                 :max_exorcism_level, :limit, :rarity, :ax, :ax_type, :gacha, :promotions,
                 :forge_order, :extra, :series, :promotion_names
      end

      # Minimal view for party list cards — just enough for image rendering
      view :list do
        excludes :name, :proficiency, :max_level, :max_skill_level, :max_awakening_level,
                 :max_exorcism_level, :limit, :rarity, :ax, :ax_type, :gacha, :promotions,
                 :forge_order, :extra, :series, :promotion_names
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

      view :grid do
        include_view :dates

        field :forged_from do |w|
          next nil unless w.forged_from.present?

          parent = w.base_weapon
          next nil unless parent

          {
            id: parent.id,
            granblue_id: parent.granblue_id,
            name: {
              en: parent.name_en,
              ja: parent.name_jp
            }
          }
        end

        field :recruits do |w|
          next nil unless w.recruits.present?

          character = w.recruited_character
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

      view :full do
        include_view :stats
        include_view :grid
        field :awakenings do |weapon|
          AwakeningBlueprint.render_as_hash(weapon.awakenings)
        end

        field :weapon_skills do |weapon|
          WeaponSkillBlueprint.render_as_hash(weapon.weapon_skills)
        end

        field :nicknames do |w|
          {
            en: w.nicknames_en,
            ja: w.nicknames_jp
          }
        end

        field :wiki do |w|
          {
            en: w.wiki_en,
            ja: w.wiki_ja
          }
        end

        fields :gamewith, :kamigame

        field :forge_chain do |w|
          next nil unless w.forge_chain_id.present?

          w.forge_chain_weapons.select { |fw| fw.element == w.element }.sort_by(&:forge_order).map do |weapon|
            {
              id: weapon.id,
              granblue_id: weapon.granblue_id,
              name: {
                en: weapon.name_en,
                ja: weapon.name_jp
              },
              forge_order: weapon.forge_order
            }
          end
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
