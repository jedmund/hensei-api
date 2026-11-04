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
      # Each attribute and how its CSV column (of the same name) is parsed.
      COLUMNS = {
        name_en: :value,
        name_jp: :value,
        granblue_id: :value,
        rarity: :integer,
        element: :integer,
        proficiency: :integer,
        series: :value,
        flb: :boolean,
        ulb: :boolean,
        max_level: :integer,
        max_skill_level: :integer,
        min_hp: :integer,
        max_hp: :integer,
        max_hp_flb: :integer,
        max_hp_ulb: :integer,
        min_atk: :integer,
        max_atk: :integer,
        max_atk_flb: :integer,
        max_atk_ulb: :integer,
        extra: :boolean,
        limit: :boolean,
        recruits: :value,
        max_awakening_level: :integer,
        release_date: :value,
        flb_date: :value,
        ulb_date: :value,
        wiki_en: :value,
        wiki_ja: :value,
        gamewith: :value,
        kamigame: :value,
        nicknames_en: :array,
        nicknames_jp: :array,
        transcendence: :boolean,
        transcendence_date: :value,
        promotions: :integer_array
      }.freeze

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
      # @option attributes [Boolean] :transcendence Flag for transcendence status
      # @option attributes [Integer] :max_level Maximum level of the weapon
      # @option attributes [Integer] :max_skill_level Maximum skill level
      # @option attributes [Integer] :max_awakening_level Maximum awakening level
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
      # @option attributes [Array<Integer>] :promotions Gacha promotions (pool membership)
      #
      # @raise [ImportError] If required attributes are missing or invalid
      def build_attributes(row)
        parse_columns(row, COLUMNS)
      end
    end
  end
end
