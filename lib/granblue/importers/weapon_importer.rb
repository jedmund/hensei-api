# frozen_string_literal: true

module Granblue
  module Importers
    # Imports weapon data from CSV files into the Weapon model
    #
    # @example Importing weapon data
    #   importer = WeaponImporter.new("weapons.csv")
    #   results = importer.import
    #
    # @see BaseImporter Base class with core import logic
    class WeaponImporter < BaseImporter
      private

      # Returns the model class for weapon records
      #
      # @return [Class] The Weapon model class
      # @note Overrides the abstract method from BaseImporter
      def model_class
        Weapon
      end

      # Builds attribute hash from a CSV row for weapon import
      #
      # @param row [CSV::Row] A single row from the weapon CSV file
      # @return [Hash] A hash of attributes ready for model creation/update
      # @option attributes [String] :name_en English name of the weapon
      # @option attributes [String] :name_jp Japanese name of the weapon
      # @option attributes [String] :granblue_id Unique identifier for the weapon
      # @option attributes [Integer] :rarity Weapon's rarity level
      # @option attributes [Integer] :element Weapon's elemental affinity
      # @option attributes [Integer] :proficiency Weapon proficiency type
      # @option attributes [Integer] :series Weapon series or collection
      # @option attributes [Boolean] :flb Flag for FLB status
      # @option attributes [Boolean] :ulb Flag for ULB status
      # @option attributes [Boolean] :extra Flag indicating whether weapon can be slotted in Extra slots
      # @option attributes [Boolean] :limit Flag indicating only one of this weapon can be equipped at once
      # @option attributes [Boolean] :ax Flag indicating whether weapon supports AX skills
      # @option attributes [Boolean] :transcendence Flag for transcendence status
      # @option attributes [Integer] :max_level Maximum level of the weapon
      # @option attributes [Integer] :max_skill_level Maximum skill level
      # @option attributes [Integer] :max_awakening_level Maximum awakening level
      # @option attributes [Integer] :ax_type AX type classification
      # @option attributes [Integer] :min_hp Minimum HP
      # @option attributes [Integer] :max_hp Maximum HP
      # @option attributes [Integer] :max_hp_flb Maximum HP after FLB
      # @option attributes [Integer] :max_hp_ulb Maximum HP after ULB
      # @option attributes [Integer] :min_atk Minimum attack
      # @option attributes [Integer] :max_atk Maximum attack
      # @option attributes [Integer] :max_atk_flb Maximum attack after FLB
      # @option attributes [Integer] :max_atk_ulb Maximum attack after ULB
      # @option attributes [String] :recruits The granblue_id of the character this weapon recruits, if any
      # @option attributes [String] :release_date Weapon release date
      # @option attributes [String] :flb_date Date FLB was implemented
      # @option attributes [String] :ulb_date Date ULB was implemented
      # @option attributes [String] :transcendence_date Date transcendence was implemented
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
          proficiency: parse_integer(row['proficiency']),
          series: parse_integer(row['series']),
          flb: parse_boolean(row['flb']),
          ulb: parse_boolean(row['ulb']),
          max_level: parse_integer(row['max_level']),
          max_skill_level: parse_integer(row['max_skill_level']),
          min_hp: parse_integer(row['min_hp']),
          max_hp: parse_integer(row['max_hp']),
          max_hp_flb: parse_integer(row['max_hp_flb']),
          max_hp_ulb: parse_integer(row['max_hp_ulb']),
          min_atk: parse_integer(row['min_atk']),
          max_atk: parse_integer(row['max_atk']),
          max_atk_flb: parse_integer(row['max_atk_flb']),
          max_atk_ulb: parse_integer(row['max_atk_ulb']),
          extra: parse_boolean(row['extra']),
          ax_type: parse_integer(row['ax_type']),
          limit: parse_boolean(row['limit']),
          ax: parse_boolean(row['ax']),
          recruits: parse_value(row['recruits']),
          max_awakening_level: parse_integer(row['max_awakening_level']),
          release_date: parse_value(row['release_date']),
          flb_date: parse_value(row['flb_date']),
          ulb_date: parse_value(row['ulb_date']),
          wiki_en: parse_value(row['wiki_en']),
          wiki_ja: parse_value(row['wiki_ja']),
          gamewith: parse_value(row['gamewith']),
          kamigame: parse_value(row['kamigame']),
          nicknames_en: parse_array(row['nicknames_en']),
          nicknames_jp: parse_array(row['nicknames_jp']),
          transcendence: parse_boolean(row['transcendence']),
          transcendence_date: parse_value(row['transcendence_date'])
        }
      end
    end
  end
end
