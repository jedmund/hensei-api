# frozen_string_literal: true

module Granblue
  module Parsers
    # SuggestionParser extracts structured suggestions from wiki text
    # for use in batch entity import flows
    class SuggestionParser
      # Parse character wiki text into suggestion fields
      def self.parse_character(wiki_text)
        return {} if wiki_text.blank?

        data = parse_wiki_text(wiki_text)

        suggestions = {}
        suggestions[:name_en] = data['name'] if data['name'].present?
        suggestions[:name_jp] = data['jpname'] if data['jpname'].present?
        suggestions[:granblue_id] = data['id'] if data['id'].present?

        # Character ID (for linking related characters)
        if data['charid'].present?
          char_ids = data['charid'].scan(/\b\d{4}\b/)
          suggestions[:character_id] = char_ids if char_ids.any?
        end

        # Rarity
        suggestions[:rarity] = Wiki.rarities[data['rarity']] if data['rarity'].present?

        # Element - capitalize first letter for case-insensitive lookup
        if data['element'].present?
          element_key = data['element'].strip.capitalize
          suggestions[:element] = Wiki.elements[element_key]
        end

        # Gender
        suggestions[:gender] = Wiki.genders[data['gender']] if data['gender'].present?

        # Proficiencies
        if data['weapon'].present?
          profs = data['weapon'].split(',').map(&:strip)
          suggestions[:proficiency1] = Wiki.proficiencies[profs[0]] if profs[0]
          suggestions[:proficiency2] = Wiki.proficiencies[profs[1]] if profs[1]
        end

        # Races
        if data['race'].present?
          races = data['race'].split(',').map(&:strip)
          suggestions[:race1] = Wiki.races[races[0]] if races[0]
          suggestions[:race2] = Wiki.races[races[1]] if races[1]
        end

        # Stats
        suggestions[:min_hp] = data['min_hp'].to_i if data['min_hp'].present?
        suggestions[:max_hp] = data['max_hp'].to_i if data['max_hp'].present?
        suggestions[:max_hp_flb] = data['flb_hp'].to_i if data['flb_hp'].present?
        suggestions[:min_atk] = data['min_atk'].to_i if data['min_atk'].present?
        suggestions[:max_atk] = data['max_atk'].to_i if data['max_atk'].present?
        suggestions[:max_atk_flb] = data['flb_atk'].to_i if data['flb_atk'].present?

        # Uncap status - characters use max_evo (5=FLB, 6=ULB)
        if data['max_evo'].present?
          evo = data['max_evo'].to_i
          suggestions[:flb] = evo >= 5
          suggestions[:ulb] = evo >= 6
        end
        # Fallback to legacy 5star field if max_evo not present
        suggestions[:flb] ||= Wiki.boolean.fetch(data['5star'], false) if data['5star'].present?

        # Series - character series like "grand", "zodiac", etc.
        # The |series= field can be comma-separated (e.g., "evoker,summer")
        if data['series'].present?
          series_values = data['series'].to_s.downcase.split(',').map(&:strip)
          series = series_values.map { |s| Wiki.character_series[s] }.compact
          suggestions[:series] = series.uniq.sort if series.any?
        end

        # Dates
        suggestions[:release_date] = parse_date(data['release_date']) if data['release_date'].present?
        suggestions[:flb_date] = parse_date(data['5star_date']) if data['5star_date'].present?
        suggestions[:ulb_date] = parse_date(data['6star_date']) if data['6star_date'].present?

        # External links - parse URLs to extract values
        suggestions[:gamewith] = parse_gamewith_url(data['link_gamewith']) if data['link_gamewith'].present?
        suggestions[:kamigame] = parse_kamigame_url(data['link_kamigame'], :character) if data['link_kamigame'].present?

        # Gacha fields - parse from obtain and series fields
        obtain = data['obtain'].to_s.downcase
        wiki_series = data['series'].to_s.downcase.strip

        # Season (from series field)
        suggestions[:season] = character_season_from_series(wiki_series, obtain)

        # Promotions (from obtain and series fields)
        promotions = character_promotions_from_obtain(obtain, wiki_series)
        suggestions[:promotions] = promotions if promotions.any?

        suggestions.compact
      end

      # Parse weapon wiki text into suggestion fields
      def self.parse_weapon(wiki_text)
        return {} if wiki_text.blank?

        data = parse_wiki_text(wiki_text)

        suggestions = {}
        suggestions[:name_en] = data['name'] if data['name'].present?
        suggestions[:name_jp] = data['jpname'] if data['jpname'].present?
        suggestions[:granblue_id] = data['id'] if data['id'].present?

        # Rarity
        suggestions[:rarity] = Wiki.rarities[data['rarity']] if data['rarity'].present?

        # Element - capitalize first letter for case-insensitive lookup
        if data['element'].present?
          element_key = data['element'].strip.capitalize
          suggestions[:element] = Wiki.elements[element_key]
        end

        # Proficiency (weapon type) - wiki uses |weapon= field, not |type=
        if data['weapon'].present?
          proficiency_key = data['weapon'].strip.capitalize
          suggestions[:proficiency] = Wiki.proficiencies[proficiency_key]
        end

        # Stats - weapons use hp1/hp2/hp3/hp4 and atk1/atk2/atk3/atk4
        suggestions[:min_hp] = data['hp1'].to_i if data['hp1'].present?
        suggestions[:max_hp] = data['hp2'].to_i if data['hp2'].present?
        suggestions[:max_hp_flb] = data['hp3'].to_i if data['hp3'].present?
        suggestions[:max_hp_ulb] = data['hp4'].to_i if data['hp4'].present?
        suggestions[:min_atk] = data['atk1'].to_i if data['atk1'].present?
        suggestions[:max_atk] = data['atk2'].to_i if data['atk2'].present?
        suggestions[:max_atk_flb] = data['atk3'].to_i if data['atk3'].present?
        suggestions[:max_atk_ulb] = data['atk4'].to_i if data['atk4'].present?

        # Uncap status - weapons use evo_max (4=FLB, 5=ULB)
        if data['evo_max'].present?
          evo = data['evo_max'].to_i
          suggestions[:flb] = evo >= 4
          suggestions[:ulb] = evo >= 5
        end

        # Series (e.g., "Revenant", "Optimus", etc.)
        suggestions[:series] = data['series'] if data['series'].present?

        # Dates
        suggestions[:release_date] = parse_date(data['release_date']) if data['release_date'].present?
        suggestions[:flb_date] = parse_date(data['4star_date']) if data['4star_date'].present?
        suggestions[:ulb_date] = parse_date(data['5star_date']) if data['5star_date'].present?

        # External links - parse URLs to extract values
        suggestions[:gamewith] = parse_gamewith_url(data['link_gamewith']) if data['link_gamewith'].present?
        suggestions[:kamigame] = parse_kamigame_url(data['link_kamigame'], :weapon) if data['link_kamigame'].present?

        # Recruits (character recruited by this weapon)
        suggestions[:recruits] = data['recruit'] if data['recruit'].present?

        suggestions.compact
      end

      # Parse summon wiki text into suggestion fields
      def self.parse_summon(wiki_text)
        return {} if wiki_text.blank?

        data = parse_wiki_text(wiki_text)

        suggestions = {}
        suggestions[:name_en] = data['name'] if data['name'].present?
        suggestions[:name_jp] = data['jpname'] if data['jpname'].present?
        suggestions[:granblue_id] = data['id'] if data['id'].present?
        suggestions[:summon_id] = data['summonid'] if data['summonid'].present?

        # Rarity
        suggestions[:rarity] = Wiki.rarities[data['rarity']] if data['rarity'].present?

        # Element - capitalize first letter for case-insensitive lookup
        if data['element'].present?
          element_key = data['element'].strip.capitalize
          suggestions[:element] = Wiki.elements[element_key]
        end

        # Stats - summons use hp1/hp2/hp3/hp4/hp5 and atk1/atk2/atk3/atk4/atk5
        suggestions[:min_hp] = data['hp1'].to_i if data['hp1'].present?
        suggestions[:max_hp] = data['hp2'].to_i if data['hp2'].present?
        suggestions[:max_hp_flb] = data['hp3'].to_i if data['hp3'].present?
        suggestions[:max_hp_ulb] = data['hp4'].to_i if data['hp4'].present?
        suggestions[:min_atk] = data['atk1'].to_i if data['atk1'].present?
        suggestions[:max_atk] = data['atk2'].to_i if data['atk2'].present?
        suggestions[:max_atk_flb] = data['atk3'].to_i if data['atk3'].present?
        suggestions[:max_atk_ulb] = data['atk4'].to_i if data['atk4'].present?

        # Uncap status - summons use max_evo (4=FLB, 5=ULB, 6=transcendence)
        if data['max_evo'].present?
          evo = data['max_evo'].to_i
          suggestions[:flb] = evo >= 4
          suggestions[:ulb] = evo >= 5
          suggestions[:transcendence] = evo >= 6
        end

        # Series (e.g., "Optimus", "Arcarum", etc.)
        suggestions[:series] = data['series'] if data['series'].present?

        # Sub-aura
        suggestions[:subaura] = Wiki.boolean.fetch(data['subaura'], false) if data['subaura'].present?

        # Dates
        suggestions[:release_date] = parse_date(data['release_date']) if data['release_date'].present?
        suggestions[:flb_date] = parse_date(data['4star_date']) if data['4star_date'].present?
        suggestions[:ulb_date] = parse_date(data['5star_date']) if data['5star_date'].present?

        # External links - parse URLs to extract values
        suggestions[:gamewith] = parse_gamewith_url(data['link_gamewith']) if data['link_gamewith'].present?
        suggestions[:kamigame] = parse_kamigame_url(data['link_kamigame'], :summon) if data['link_kamigame'].present?

        suggestions.compact
      end

      # Parse wiki text into a key-value hash
      def self.parse_wiki_text(wiki_text)
        lines = wiki_text.split("\n")
        data = {}
        stop_loop = false

        lines.each do |line|
          next if stop_loop

          # Stop parsing at gameplay notes section
          if line.include?('Gameplay Notes')
            stop_loop = true
            next
          end

          next unless line[0] == '|' && line.size > 2

          key, value = line[1..].split('=', 2).map(&:strip)
          data[key] = value if value.present?
        end

        data
      end

      # Parse a date string into a Date object
      def self.parse_date(date_str)
        Date.parse(date_str)
      rescue ArgumentError, TypeError
        nil
      end

      # Parse Gamewith value to extract article ID
      # Handles multiple formats:
      # - Full URL: https://xn--bck3aza1a2if6kra4ee0hf.gamewith.jp/article/show/519325
      # - Direct numeric ID: 519325
      # - Template syntax: {{{link_gamewith|519325}}}
      # Output: "519325"
      def self.parse_gamewith_url(value)
        return nil if value.blank?

        value = value.to_s.strip

        # Handle MediaWiki template syntax {{{link_gamewith|VALUE}}}
        if value =~ /\{\{\{link_gamewith\|(\d+)\}\}\}/
          return $1
        end

        # If it's a full URL, extract the ID
        if value =~ /gamewith\.jp\/article\/show\/(\d+)/
          $1
        # If it's already just a numeric ID, return it
        elsif value =~ /^\d+$/
          value
        end
      end

      # Parse Kamigame value to extract Japanese slug
      # Handles multiple formats:
      # - Full URL: https://kamigame.jp/グラブル/キャラクター/SSR水着リッチ.html
      # - Direct Japanese slug: SSR水着リッチ or SSR/アグニス
      # - Template syntax: {{{link_kamigame|VALUE}}}
      # entity_type: :character, :weapon, :summon
      def self.parse_kamigame_url(value, entity_type)
        return nil if value.blank?

        value = value.to_s.strip

        # Handle MediaWiki template syntax {{{link_kamigame|VALUE}}}
        # This may contain nested templates like {{{jpname|}}}
        if value =~ /\{\{\{link_kamigame\|([^}]*)\}\}\}/
          extracted = $1
          # If the extracted value contains nested templates, skip it
          return nil if extracted.include?('{{{')
          return nil if extracted.blank?
          value = extracted
        end

        # URL decode to handle percent-encoded Japanese characters
        decoded = URI.decode_www_form_component(value)

        # Check if it's a full URL
        if decoded.include?('kamigame.jp')
          case entity_type
          when :character
            # https://kamigame.jp/グラブル/キャラクター/SSR水着リッチ.html -> SSR水着リッチ
            if decoded =~ /キャラクター\/([^\/]+)\.html$/
              $1
            end
          when :weapon
            # https://kamigame.jp/グラブル/武器/SSR/ブラインド.html -> ブラインド
            if decoded =~ /武器\/(?:SSR|SR|R)\/([^\/]+)\.html$/
              $1
            end
          when :summon
            # https://kamigame.jp/グラブル/召喚石/SSR/アグニス.html -> SSR/アグニス
            if decoded =~ /召喚石\/((?:SSR|SR|R)\/[^\/]+)\.html$/
              $1
            end
          end
        else
          # Assume it's already just the slug value
          # Remove .html extension if present
          decoded.sub(/\.html$/, '')
        end
      rescue ArgumentError
        # Handle invalid URL encoding
        nil
      end

      # Seasonal series that indicate a character is only available during that season
      SEASONAL_SERIES = %w[holiday summer valentine halloween formal].freeze

      # Maps series values to CharacterSeason enum values
      SEASON_MAP = {
        'valentine' => 1,
        'formal' => 2,
        'summer' => 3,
        'halloween' => 4,
        'holiday' => 5
      }.freeze

      # Maps series to Promotion enum values for seasonal characters
      SEASONAL_PROMOTION_MAP = {
        'holiday' => 9,
        'summer' => 7,
        'valentine' => 6,
        'halloween' => 8,
        'formal' => 11
      }.freeze

      # Indicators in obtain field that mean character is gacha-available
      GACHA_INDICATORS = %w[premium flash legend classic classic2 grand zodiac valentine summer halloween holiday formal normal].freeze

      # Non-gacha obtain values
      NON_GACHA_INDICATORS = %w[rotb event side story promo eternal evoker archangel].freeze

      # Extract season from wiki series field
      # @param wiki_series [String] The series field value (e.g., "holiday", "summer")
      # @param obtain [String] The obtain field value
      # @return [Integer, nil] CharacterSeason enum value, or nil for non-seasonal characters
      def self.character_season_from_series(wiki_series, obtain)
        # Check series field first
        return SEASON_MAP[wiki_series] if SEASON_MAP.key?(wiki_series)

        # Check obtain field for seasonal indicators
        SEASON_MAP.each do |series, season_id|
          return season_id if obtain.include?(series)
        end

        # Non-seasonal characters have nil season
        nil
      end

      # Determine if character can be pulled from gacha
      # @param obtain [String] The obtain field value
      # @param wiki_series [String] The series field value
      # @return [Boolean]
      def self.gacha_available_from_obtain(obtain, wiki_series)
        return false if obtain.blank?

        # Check for non-gacha indicators
        return false if NON_GACHA_INDICATORS.any? { |indicator| obtain.include?(indicator) }

        # Check for gacha indicators
        GACHA_INDICATORS.any? { |indicator| obtain.include?(indicator) }
      end

      # Extract promotions array from obtain and series fields
      # @param obtain [String] The obtain field value
      # @param wiki_series [String] The series field value
      # @return [Array<Integer>] Array of Promotion enum values
      def self.character_promotions_from_obtain(obtain, wiki_series)
        return [] unless gacha_available_from_obtain(obtain, wiki_series)

        promotions = []

        # Seasonal characters ONLY get their seasonal promotion
        if SEASONAL_SERIES.include?(wiki_series)
          promotions << SEASONAL_PROMOTION_MAP[wiki_series] if SEASONAL_PROMOTION_MAP[wiki_series]
          return promotions
        end

        # Check if obtain indicates a seasonal banner (e.g., obtain=premium,holiday)
        SEASONAL_SERIES.each do |series|
          if obtain.include?(series)
            promotions << SEASONAL_PROMOTION_MAP[series] if SEASONAL_PROMOTION_MAP[series]
            return promotions
          end
        end

        # Standard characters get Premium, Flash, Legend by default
        promotions << 1 # Premium
        promotions << 4 # Flash
        promotions << 5 # Legend

        # Add Classic pools only if explicitly mentioned
        promotions << 2 if obtain.include?('classic') && !obtain.include?('classic2')
        promotions << 3 if obtain.include?('classic2')

        promotions.uniq.sort
      end
    end
  end
end
