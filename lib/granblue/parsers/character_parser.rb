# frozen_string_literal: true

require 'pry'

module Granblue
  module Parsers
    # CharacterParser parses character data from gbf.wiki
    class CharacterParser
      attr_reader :granblue_id

      def initialize(granblue_id: String, debug: false)
        @character = Character.find_by(granblue_id: granblue_id)
        @wiki = Granblue::Parsers::Wiki.new
        @debug = debug || false
      end

      # Fetches using @wiki and then processes the response
      # Returns true if successful, false if not
      # Raises an exception if something went wrong
      def fetch(save: false)
        response = fetch_wiki_info
        return false if response.nil?

        redirect = handle_redirected_string(response)
        return fetch(save: save) unless redirect.nil?

        handle_fetch_success(response, save)
      end

      private

      # Determines whether or not the response is a redirect
      # If it is, it will update the character's wiki_en value
      def handle_redirected_string(response)
        redirect = extract_redirected_string(response)
        return unless redirect

        @character.wiki_en = redirect
        if @character.save!
          ap "Saved new wiki_en value for #{@character.granblue_id}: #{redirect}" if @debug
          redirect
        else
          ap "Unable to save new wiki_en value for #{@character.granblue_id}: #{redirect}" if @debug
          nil
        end
      end

      # Handle the response from the wiki if the response is successful
      # If the save flag is set, it will persist the data to the database
      def handle_fetch_success(response, save)
        ap "#{@character.granblue_id}: Successfully fetched info for #{@character.wiki_en}" if @debug
        extracted = parse_string(response)
        info = parse(extracted)
        persist(info) if save
        true
      end

      # Determines whether the response string
      # should be treated as a redirect
      def extract_redirected_string(string)
        string.match(/#REDIRECT \[\[(.*?)\]\]/)&.captures&.first
      end

      # Parses the response string into a hash
      def parse_string(string)
        lines = string.split("\n")
        data = {}
        stop_loop = false

        lines.each do |line|
          next if stop_loop

          if line.include?('Gameplay Notes')
            stop_loop = true
            next
          end

          next unless line[0] == '|' && line.size > 2

          key, value = line[1..].split('=', 2).map(&:strip)
          data[key] = value if value
        end

        data
      end

      # Fetches data from the GranblueWiki object
      def fetch_wiki_info
        @wiki.fetch(@character.wiki_en)
      rescue WikiError => e
        ap "There was an error fetching #{e.page}: #{e.message}" if @debug
        nil
      end

      # Iterates over all characters in the database and fetches their data
      # If the save flag is set, data is saved to the database
      # If the overwrite flag is set, data is fetched even if it already exists
      # If the debug flag is set, additional information is printed to the console
      def self.fetch_all(save: false, overwrite: false, debug: false)
        errors = []

        count = Character.count
        Character.all.each_with_index do |c, i|
          percentage = ((i + 1) / count.to_f * 100).round(2)
          ap "#{percentage}%: Fetching #{c.name_en}... (#{i + 1}/#{count})" if debug
          next unless c.release_date.nil? || overwrite

          begin
            CharacterParser.new(granblue_id: c.granblue_id,
                                debug: debug).fetch(save: save)
          rescue WikiError => e
            errors.push(e.page)
          end
        end

        ap 'The following pages were unable to be fetched:'
        ap errors
      end

      def self.fetch_list(list: [], save: false, overwrite: false, debug: false, start: nil)
        errors = []

        start_index = start.nil? ? 0 : list.index { |id| id == start }
        count = list.drop(start_index).count

        # ap "Start index: #{start_index}"

        list.drop(start_index).each_with_index do |id, i|
          chara = Character.find_by(granblue_id: id)
          percentage = ((i + 1) / count.to_f * 100).round(2)
          ap "#{percentage}%: Fetching #{chara.wiki_en}... (#{i + 1}/#{count})" if debug
          next unless chara.release_date.nil? || overwrite

          begin
            WeaponParser.new(granblue_id: chara.granblue_id,
                             debug: debug).fetch(save: save)
          rescue WikiError => e
            errors.push(e.page)
          end
        end

        ap 'The following pages were unable to be fetched:'
        ap errors
      end

      # Parses the hash into a format that can be saved to the database
      def parse(hash)
        info = {}

        info[:name] = { en: hash['name'], ja: hash['jpname'] }
        info[:id] = hash['id']
        info[:charid] = hash['charid'].scan(/\b\d{4}\b/)

        info[:flb] = GranblueWiki.boolean.fetch(hash['5star'], false)
        info[:ulb] = hash['max_evo'].to_i == 6

        info[:rarity] = GranblueWiki.rarities.fetch(hash['rarity'], 0)
        info[:element] = GranblueWiki.elements.fetch(hash['element'], 0)
        info[:gender] = GranblueWiki.genders.fetch(hash['gender'], 0)

        info[:proficiencies] = proficiencies_from_hash(hash['weapon'])
        info[:races] = races_from_hash(hash['race'])

        info[:hp] = {
          min_hp: hash['min_hp'].to_i,
          max_hp: hash['max_hp'].to_i,
          max_hp_flb: hash['flb_hp'].to_i
        }

        info[:atk] = {
          min_atk: hash['min_atk'].to_i,
          max_atk: hash['max_atk'].to_i,
          max_atk_flb: hash['flb_atk'].to_i
        }

        info[:dates] = {
          release_date: parse_date(hash['release_date']),
          flb_date: parse_date(hash['5star_date']),
          ulb_date: parse_date(hash['6star_date'])
        }

        info[:links] = {
          wiki: { en: hash['name'], ja: hash['link_jpwiki'] },
          gamewith: hash['link_gamewith'],
          kamigame: hash['link_kamigame']
        }

        info.compact
      end

      # Saves select fields to the database
      def persist(hash)
        @character.release_date = hash[:dates][:release_date]
        @character.flb_date = hash[:dates][:flb_date] if hash[:dates].key?(:flb_date)
        @character.ulb_date = hash[:dates][:ulb_date] if hash[:dates].key?(:ulb_date)

        @character.wiki_ja = hash[:links][:wiki][:ja] if hash[:links].key?(:wiki) && hash[:links][:wiki].key?(:ja)
        @character.gamewith = hash[:links][:gamewith] if hash[:links].key?(:gamewith)
        @character.kamigame = hash[:links][:kamigame] if hash[:links].key?(:kamigame)

        if @character.save
          ap "#{@character.granblue_id}: Successfully saved info for #{@character.name_en}" if @debug
          puts
          true
        end

        false
      end

      # Converts proficiencies from a string to a hash
      def proficiencies_from_hash(character)
        character.to_s.split(',').map.with_index do |prof, i|
          { "proficiency#{i + 1}" => GranblueWiki.proficiencies[prof] }
        end.reduce({}, :merge)
      end

      # Converts races from a string to a hash
      def races_from_hash(race)
        race.to_s.split(',').map.with_index do |r, i|
          { "race#{i + 1}" => GranblueWiki.races[r] }
        end.reduce({}, :merge)
      end

      # Parses a date string into a Date object
      def parse_date(date_str)
        Date.parse(date_str) unless date_str.blank?
      end

      # Unused methods for now
      def extract_abilities(hash)
        abilities = []
        hash.each do |key, value|
          next unless key =~ /^a(\d+)_/

          ability_number = Regexp.last_match(1).to_i
          abilities[ability_number] ||= {}

          case key.gsub(/^a\d+_/, '')
          when 'cd'
            cooldown = parse_substring(value)
            abilities[ability_number]['cooldown'] = cooldown
          when 'dur'
            duration = parse_substring(value)
            abilities[ability_number]['duration'] = duration
          when 'oblevel'
            obtained = parse_substring(value)
            abilities[ability_number]['obtained'] = obtained
          else
            abilities[ability_number][key.gsub(/^a\d+_/, '')] = value
          end
        end

        { 'abilities' => abilities.compact }
      end

      def parse_substring(string)
        hash = {}

        string.scan(/\|([^|=]+?)=([^|]+)/) do |key, value|
          value.gsub!(/\}\}$/, '') if value.include?('}}')
          hash[key] = value
        end

        hash
      end

      def extract_ougis(hash)
        ougi = []
        hash.each do |key, value|
          next unless key =~ /^ougi(\d*)_(.*)/

          ougi_number = Regexp.last_match(1)
          ougi_key = Regexp.last_match(2)
          ougi[ougi_number.to_i] ||= {}
          ougi[ougi_number.to_i][ougi_key] = value
        end

        { 'ougis' => ougi.compact }
      end
    end
  end
end
