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
        'grand' => 1,       # Grand
        'zodiac' => 2,      # Zodiac
        'promo' => 3,       # Promo
        'collab' => 4,      # Collab
        'eternal' => 5,     # Eternal
        'evoker' => 6,      # Evoker
        'archangel' => 7,   # Saint (Archangels)
        'fantasy' => 8,     # Fantasy
        'summer' => 9,      # Summer
        'yukata' => 10,     # Yukata
        'valentine' => 11,  # Valentine
        'halloween' => 12,  # Halloween
        'formal' => 13,     # Formal
        'holiday' => 14,    # Holiday
        'event' => 15       # Event
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

      # Pools an ordinary Premium item appears in: every banner but Classic
      # (Flash, Legend, each season and Collab draws all include Premium)
      ORDINARY_PROMOTIONS = [1, 4, 5, 6, 7, 8, 9, 10, 11].freeze

      # Wiki |obtain= tokens for limited pools, and the pool each maps to
      LIMITED_PROMOTIONS = {
        'valentine' => 6,
        'summer' => 7,
        'swimsuit' => 7,
        'halloween' => 8,
        'holiday' => 9,
        'formal' => 11
      }.freeze

      # Maps a wiki |obtain= value (e.g. "premium,gala,flash") to PROMOTIONS
      # enum values, matching how the curated catalogue stores pools:
      # - limited items only appear in their limited pool, never in Premium:
      #   gala,flash is Flash Gala; gala,normal, legend and zodiac are Legend
      #   Festival; a season token is that season's pool
      # - premium,collab is the Collab draw; other collab items are event rewards
      # - premium,normal items appear in every Premium-type banner; other
      #   premium variants (ticket-only, special draw sets) are in no pool
      # - Classic pools are added only when the wiki names them
      # @return [Array<Integer>]
      def self.promotions_from_obtain(obtain)
        tokens = obtain.to_s.downcase.split(/[,;]/).map(&:strip)

        premium = tokens.include?('premium')
        limited = tokens.filter_map { |token| LIMITED_PROMOTIONS[token] }
        limited << 10 if premium && tokens.include?('collab')
        limited << 4 if tokens.include?('flash')
        if tokens.include?('legend') || tokens.include?('zodiac') || (tokens.include?('gala') && !tokens.include?('flash'))
          limited << 5
        end
        return limited.uniq.sort if limited.any?

        return [] if tokens.include?('collab')

        promotions = premium && tokens.include?('normal') ? ORDINARY_PROMOTIONS.dup : []
        promotions << 2 if tokens.include?('classic')
        promotions << 3 if tokens.include?('classic2')
        promotions << 12 if tokens.include?('classic3')
        promotions.uniq.sort
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

        response = HTTParty.get(destination, headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent })

        handle_response(response, page)
      end

      # Expand the templates in a chunk of wikitext (action=expandtemplates) — resolves the
      # {{Weapon/Common/<Series>}} wrapper so series-template skills (Bahamut/Xeno/Militis/…)
      # render their skill rows. Returns the expanded wikitext/HTML, or nil on error.
      def expand(text)
        response = HTTParty.post(base_uri,
                                 body: { action: 'expandtemplates', format: 'json',
                                         prop: 'wikitext', text: text },
                                 headers: { 'User-Agent' => Rails.application.credentials.wiki_user_agent })
        return nil unless response.code == 200

        JSON.parse(response.body).dig('expandtemplates', 'wikitext')
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
