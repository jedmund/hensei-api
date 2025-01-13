# frozen_string_literal: true

module Granblue
  module Importers
    class SummonsImporter < BaseImporter
      private

      def model_class
        Summon
      end

      def build_attributes(row)
        {
          name_en: parse_value(row['name_en']),
          name_jp: parse_value(row['name_jp']),
          granblue_id: parse_value(row['granblue_id']),
          rarity: parse_integer(row['rarity']),
          element: parse_integer(row['element']),
          series: parse_value(row['series']),
          flb: parse_boolean(row['flb']),
          ulb: parse_boolean(row['ulb']),
          max_level: parse_integer(row['max_level']),
          min_hp: parse_integer(row['min_hp']),
          max_hp: parse_integer(row['max_hp']),
          max_hp_flb: parse_integer(row['max_hp_flb']),
          max_hp_ulb: parse_integer(row['max_hp_ulb']),
          min_atk: parse_integer(row['min_atk']),
          max_atk: parse_integer(row['max_atk']),
          max_atk_flb: parse_integer(row['max_atk_flb']),
          max_atk_ulb: parse_integer(row['max_atk_ulb']),
          subaura: parse_boolean(row['subaura']),
          limit: parse_boolean(row['limit']),
          transcendence: parse_boolean(row['transcendence']),
          max_atk_xlb: parse_integer(row['max_atk_xlb']),
          max_hp_xlb: parse_integer(row['max_hp_xlb']),
          summon_id: parse_integer(row['summon_id']),
          release_date: parse_value(row['release_date']),
          flb_date: parse_value(row['flb_date']),
          ulb_date: parse_value(row['ulb_date']),
          wiki_en: parse_value(row['wiki_en']),
          wiki_ja: parse_value(row['wiki_ja']),
          gamewith: parse_value(row['gamewith']),
          kamigame: parse_value(row['kamigame']),
          transcendence_date: parse_value(row['transcendence_date']),
          nicknames_en: parse_array(row['nicknames_en']),
          nicknames_jp: parse_array(row['nicknames_jp'])
        }
      end
    end
  end
end
