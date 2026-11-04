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
      # Each attribute and how its CSV column (of the same name) is parsed.
      COLUMNS = {
        name_en: :value,
        name_jp: :value,
        granblue_id: :value,
        rarity: :integer,
        element: :integer,
        proficiency1: :integer,
        proficiency2: :integer,
        gender: :integer,
        race1: :integer,
        race2: :integer,
        flb: :boolean,
        min_hp: :integer,
        max_hp: :integer,
        max_hp_flb: :integer,
        min_atk: :integer,
        max_atk: :integer,
        max_atk_flb: :integer,
        base_da: :integer,
        base_ta: :integer,
        ougi_ratio: :float,
        ougi_ratio_flb: :float,
        special: :boolean,
        ulb: :boolean,
        transcendence: :boolean,
        max_transcendence_stage: :integer,
        max_hp_ulb: :integer,
        max_atk_ulb: :integer,
        max_hp_transcendence: :integer,
        max_atk_transcendence: :integer,
        character_id: :integer_array,
        wiki_en: :value,
        release_date: :value,
        flb_date: :value,
        ulb_date: :value,
        transcendence_date: :value,
        wiki_ja: :value,
        gamewith: :value,
        kamigame: :value,
        nicknames_en: :array,
        nicknames_jp: :array,
        season: :integer,
        series: :integer_array
      }.freeze

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
      # @option attributes [Boolean] :transcendence Flag for transcendence
      # @option attributes [Boolean] :special Flag for characters with special uncap patterns
      # @option attributes [Integer] :min_hp Minimum HP
      # @option attributes [Integer] :max_hp Maximum HP
      # @option attributes [Integer] :max_hp_flb Maximum HP after FLB
      # @option attributes [Integer] :max_hp_transcendence Maximum HP after transcendence
      # @option attributes [Integer] :min_atk Minimum attack
      # @option attributes [Integer] :max_atk Maximum attack
      # @option attributes [Integer] :max_atk_flb Maximum attack after FLB
      # @option attributes [Integer] :max_atk_transcendence Maximum attack after transcendence
      # @option attributes [Integer] :base_da Base double attack rate
      # @option attributes [Integer] :base_ta Base triple attack rate
      # @option attributes [Float] :ougi_ratio Original ougi (charge attack) ratio
      # @option attributes [Float] :ougi_ratio_flb Ougi ratio after FLB
      # @option attributes [String] :release_date Character release date
      # @option attributes [String] :flb_date Date FLB was implemented
      # @option attributes [String] :transcendence_date Date transcendence was implemented
      # @option attributes [String] :wiki_en English wiki link
      # @option attributes [String] :wiki_ja Japanese wiki link
      # @option attributes [String] :gamewith Gamewith link
      # @option attributes [String] :kamigame Kamigame link
      # @option attributes [Array<String>] :nicknames_en English nicknames
      # @option attributes [Array<String>] :nicknames_jp Japanese nicknames
      # @option attributes [Integer] :season Character season (gacha availability window)
      # @option attributes [Array<Integer>] :series Character series (identity/pool membership)
      #
      # @raise [ImportError] If required attributes are missing or invalid
      def build_attributes(row)
        attributes = parse_columns(row, COLUMNS)
        # Without transcendence a character has no transcendence stages.
        transcendence = attributes[:transcendence] || false
        attributes.merge(ulb: attributes[:ulb] || false, transcendence: transcendence,
                         max_transcendence_stage: transcendence ? attributes[:max_transcendence_stage] : 0)
      end
    end
  end
end
