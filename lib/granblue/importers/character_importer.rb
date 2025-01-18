# frozen_string_literal: true

module Granblue
  module Importers
    # Imports character data from CSV files into the Character model
    #
    # @example Importing character data
    #   importer = CharacterImporter.new("characters.csv")
    #   results = importer.import
    #
    # @see BaseImporter Base class with core import logic
    class CharacterImporter < BaseImporter
      private

      # Returns the model class for character records
      #
      # @return [Class] The Character model class
      # @note Overrides the abstract method from BaseImporter
      def model_class
        Character
      end

      # Builds attribute hash from a CSV row for character import
      #
      # @param row [CSV::Row] A single row from the character CSV file
      # @return [Hash] A hash of attributes ready for model creation/update
      # @option attributes [String] :name_en English name of the character
      # @option attributes [String] :name_jp Japanese name of the character
      # @option attributes [String] :granblue_id Unique identifier for the character
      # @option attributes [Array<Integer>] :character_id Array of character IDs
      # @option attributes [Integer] :rarity Character's rarity level
      # @option attributes [Integer] :element Character's elemental affinity
      # @option attributes [Integer] :proficiency1 First weapon proficiency
      # @option attributes [Integer] :proficiency2 Second weapon proficiency
      # @option attributes [Integer] :gender Character's gender
      # @option attributes [Integer] :race1 First character race
      # @option attributes [Integer] :race2 Second character race
      # @option attributes [Boolean] :flb Flag for FLB
      # @option attributes [Boolean] :ulb Flag for ULB
      # @option attributes [Boolean] :special Flag for characters with special uncap patterns
      # @option attributes [Integer] :min_hp Minimum HP
      # @option attributes [Integer] :max_hp Maximum HP
      # @option attributes [Integer] :max_hp_flb Maximum HP after FLB
      # @option attributes [Integer] :max_hp_ulb Maximum HP after ULB
      # @option attributes [Integer] :min_atk Minimum attack
      # @option attributes [Integer] :max_atk Maximum attack
      # @option attributes [Integer] :max_atk_flb Maximum attack after FLB
      # @option attributes [Integer] :max_atk_ulb Maximum attack after ULB
      # @option attributes [Integer] :base_da Base double attack rate
      # @option attributes [Integer] :base_ta Base triple attack rate
      # @option attributes [Float] :ougi_ratio Original ougi (charge attack) ratio
      # @option attributes [Float] :ougi_ratio_flb Ougi ratio after FLB
      # @option attributes [String] :release_date Character release date
      # @option attributes [String] :flb_date Date FLB was implemented
      # @option attributes [String] :ulb_date Date ULB was implemented
      # @option attributes [String] :wiki_en English wiki link
      # @option attributes [String] :wiki_ja Japanese wiki link
      # @option attributes [String] :gamewith Gamewith link
      # @option attributes [String] :kamigame Kamigame link
      # @option attributes [Array<String>] :nicknames_en English nicknames
      # @option attributes [Array<String>] :nicknames_jp Japanese nicknames
      #
      # @raise [ImportError] If required attributes are missing or invalid
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
