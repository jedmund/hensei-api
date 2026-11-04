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
      # Each attribute and how its CSV column (of the same name) is parsed.
      COLUMNS = {
        name_en: :value,
        name_jp: :value,
        granblue_id: :value,
        rarity: :integer,
        element: :integer,
        series: :value,
        flb: :boolean,
        ulb: :boolean,
        max_level: :integer,
        min_hp: :integer,
        max_hp: :integer,
        max_hp_flb: :integer,
        max_hp_ulb: :integer,
        min_atk: :integer,
        max_atk: :integer,
        max_atk_flb: :integer,
        max_atk_ulb: :integer,
        subaura: :boolean,
        limit: :boolean,
        transcendence: :boolean,
        max_atk_xlb: :integer,
        max_hp_xlb: :integer,
        summon_id: :integer,
        release_date: :value,
        flb_date: :value,
        ulb_date: :value,
        wiki_en: :value,
        wiki_ja: :value,
        gamewith: :value,
        kamigame: :value,
        transcendence_date: :value,
        nicknames_en: :array,
        nicknames_jp: :array,
        promotions: :integer_array
      }.freeze

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
      # @option attributes [Array<Integer>] :promotions Gacha promotions (pool membership)
      #
      # @raise [ImportError] If required attributes are missing or invalid
      def build_attributes(row)
        parse_columns(row, COLUMNS)
      end
    end
  end
end
