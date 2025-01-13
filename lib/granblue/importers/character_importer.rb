# frozen_string_literal: true

module Granblue
  module Importers
    class CharacterImporter < BaseImporter
      private

      def model_class
        Character
      end

      def build_attributes(row)
        {
          name_en: parse_value(row['name_en']),
          name_jp: parse_value(row['name_jp']),
          granblue_id: parse_value(row['granblue_id']),
          rarity: parse_integer(row['rarity']),
          element: parse_integer(row['element']),
          proficiency1: parse_integer(row['proficiency1']),
          proficiency2: parse_integer(row['proficiency2']),
          gender: parse_integer(row['gender']),
          race1: parse_integer(row['race1']),
          race2: parse_integer(row['race2']),
          flb: parse_boolean(row['flb']),
          min_hp: parse_integer(row['min_hp']),
          max_hp: parse_integer(row['max_hp']),
          max_hp_flb: parse_integer(row['max_hp_flb']),
          min_atk: parse_integer(row['min_atk']),
          max_atk: parse_integer(row['max_atk']),
          max_atk_flb: parse_integer(row['max_atk_flb']),
          base_da: parse_integer(row['base_da']),
          base_ta: parse_integer(row['base_ta']),
          ougi_ratio: parse_float(row['ougi_ratio']),
          ougi_ratio_flb: parse_float(row['ougi_ratio_flb']),
          special: parse_boolean(row['special']),
          ulb: parse_boolean(row['ulb']),
          max_hp_ulb: parse_integer(row['max_hp_ulb']),
          max_atk_ulb: parse_integer(row['max_atk_ulb']),
          character_id: parse_integer_array(row['character_id']),
          wiki_en: parse_value(row['wiki_en']),
          release_date: parse_value(row['release_date']),
          flb_date: parse_value(row['flb_date']),
          ulb_date: parse_value(row['ulb_date']),
          wiki_ja: parse_value(row['wiki_ja']),
          gamewith: parse_value(row['gamewith']),
          kamigame: parse_value(row['kamigame']),
          nicknames_en: parse_array(row['nicknames_en']),
          nicknames_jp: parse_array(row['nicknames_jp'])
        }
      end
    end
  end
end
