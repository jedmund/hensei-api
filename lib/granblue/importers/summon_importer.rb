# frozen_string_literal: true

module Granblue
  module Importers
    # Imports summon data from CSV files into the Summon model
    #
    # @example Importing summon data
    #   importer = SummonImporter.new("summons.csv")
    #   results = importer.import
    #
    # @see BaseImporter Base class with core import logic
    class SummonImporter < BaseImporter
      private

      # Returns the model class for summon records
      #
      # @return [Class] The Summon model class
      # @note Overrides the abstract method from BaseImporter
      def model_class
        Summon
      end

      # Builds attribute hash from a CSV row for summon import
      #
      # @param row [CSV::Row] A single row from the summon CSV file
      # @return [Hash] A hash of attributes ready for model creation/update
      # @option attributes [String] :name_en English name of the summon
      # @option attributes [String] :name_jp Japanese name of the summon
      # @option attributes [String] :granblue_id Unique identifier for the summon
      # @option attributes [Integer] :summon_id Specific summon identifier
      # @option attributes [Integer] :rarity Summon's rarity level
      # @option attributes [Integer] :element Summon's elemental affinity
      # @option attributes [String] :series Summon's series or collection
      # @option attributes [Boolean] :flb Flag for FLB
      # @option attributes [Boolean] :ulb Flag for ULB
      # @option attributes [Boolean] :subaura Flag indicating the presence of a subaura effect
      # @option attributes [Boolean] :limit Flag indicating only one of this summon can be equipped at once
      # @option attributes [Boolean] :transcendence Flag for transcendence status
      # @option attributes [Integer] :max_level Maximum level of the summon
      # @option attributes [Integer] :min_hp Minimum HP
      # @option attributes [Integer] :max_hp Maximum HP
      # @option attributes [Integer] :max_hp_flb Maximum HP after FLB
      # @option attributes [Integer] :max_hp_ulb Maximum HP after ULB
      # @option attributes [Integer] :max_hp_xlb Maximum HP after Transcendence
      # @option attributes [Integer] :min_atk Minimum attack
      # @option attributes [Integer] :max_atk Maximum attack
      # @option attributes [Integer] :max_atk_flb Maximum attack after FLB
      # @option attributes [Integer] :max_atk_ulb Maximum attack after ULB
      # @option attributes [Integer] :max_atk_xlb Maximum attack after Transcendence
      # @option attributes [String] :release_date Summon release date
      # @option attributes [String] :flb_date Date FLB was implemented
      # @option attributes [String] :ulb_date Date ULB was implemented
      # @option attributes [String] :transcendence_date Date Transcendence was implemented
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
