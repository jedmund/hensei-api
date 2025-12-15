# frozen_string_literal: true

require 'httparty'

# GranblueWiki fetches and parses data from gbf.wiki
module Granblue
  module Parsers
    class Wiki
      class_attribute :base_uri

      class_attribute :proficiencies
      class_attribute :elements
      class_attribute :rarities
      class_attribute :genders
      class_attribute :races
      class_attribute :bullets
      class_attribute :boolean
      class_attribute :character_series
      class_attribute :character_seasons

      self.base_uri = 'https://gbf.wiki/api.php'

      self.proficiencies = {
        'Sabre' => 1,
        'Dagger' => 2,
        'Axe' => 3,
        'Spear' => 4,
        'Bow' => 5,
        'Staff' => 6,
        'Melee' => 7,
        'Harp' => 8,
        'Gun' => 9,
        'Katana' => 10
      }.freeze

      self.elements = {
        'Wind' => 1,
        'Fire' => 2,
        'Water' => 3,
        'Earth' => 4,
        'Dark' => 5,
        'Light' => 6
      }.freeze

      self.rarities = {
        'R' => 1,
        'SR' => 2,
        'SSR' => 3
      }.freeze

      self.races = {
        'Other' => 0,
        'Human' => 1,
        'Erune' => 2,
        'Draph' => 3,
        'Harvin' => 4,
        'Primal' => 5
      }.freeze

      self.genders = {
        'o' => 0,
        'm' => 1,
        'f' => 2,
        'mf' => 3
      }.freeze

      self.bullets = {
        'cartridge' => 1,
        'rifle' => 2,
        'parabellum' => 3,
        'aetherial' => 4
      }.freeze

      self.boolean = {
        'yes' => true,
        'no' => false
      }.freeze

      # Maps wiki |series= values to CHARACTER_SERIES enum values
      # Wiki uses lowercase, single values like "grand", "zodiac", etc.
      self.character_series = {
        'normal' => 1,      # Standard
        'grand' => 2,       # Grand
        'zodiac' => 3,      # Zodiac
        'promo' => 4,       # Promo
        'collab' => 5,      # Collab
        'eternal' => 6,     # Eternal
        'evoker' => 7,      # Evoker
        'archangel' => 8,   # Saint (Archangels)
        'fantasy' => 9,     # Fantasy
        'summer' => 10,     # Summer
        'yukata' => 11,     # Yukata
        'valentine' => 12,  # Valentine
        'halloween' => 13,  # Halloween
        'formal' => 14,     # Formal
        'holiday' => 15,    # Holiday
        'event' => 16       # Event
      }.freeze

      # Maps wiki seasonal indicators to CHARACTER_SEASONS enum values
      # Used for display disambiguation (e.g., "Vane [Halloween]")
      # If no season matches, value should be nil
      self.character_seasons = {
        'valentine' => 1,   # Valentine
        'formal' => 2,      # Formal
        'summer' => 3,      # Summer (includes Yukata)
        'halloween' => 4,   # Halloween
        'holiday' => 5      # Holiday
      }.freeze

      # Maps wiki |obtain= values to PROMOTIONS enum values for weapons/summons
      # Wiki uses comma-separated values like "premium,gala,flash"
      def self.promotions
        {
          'premium' => 1,    # Premium
          'classic' => 2,    # Classic
          'classic2' => 3,   # Classic II
          'gala' => 4,       # Flash (wiki uses "gala" for Flash Gala)
          'flash' => 4,      # Flash (alternate)
          'legend' => 5,     # Legend
          'valentine' => 6,  # Valentine
          'summer' => 7,     # Summer
          'halloween' => 8,  # Halloween
          'holiday' => 9,    # Holiday
          'collab' => 10,    # Collab
          'formal' => 11     # Formal
        }.freeze
      end

      def initialize(props: ['wikitext'], debug: false)
        @debug = debug
        @props = props.join('|')
      end

      def fetch(page)
        query_params = params(page).map do |key, value|
          "#{key}=#{value}"
        end.join('&')

        destination = "#{base_uri}?#{query_params}"
        ap "--> Fetching #{destination}" if @debug

        response = HTTParty.get(destination, headers: {
          'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36'
        })

        handle_response(response, page)
      end

      private

      def handle_response(response, page)
        case response.code
        when 200
          if response.key?('error')
            raise WikiError.new(code: response['error']['code'],
                                message: response['error']['info'],
                                page: page)
          end

          response['parse']['wikitext']['*']
        when 404
          raise WikiError.new(code: 404, message: 'Page not found', page: page)
        when 500...600
          raise WikiError.new(code: response.code, message: 'Server error', page: page)
        else
          raise WikiError.new(code: response.code, message: 'Unexpected response', page: page)
        end
      end

      def params(page)
        {
          action: 'parse',
          format: 'json',
          page: page,
          prop: @props
        }
      end
    end
  end
end
