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

        # Element
        suggestions[:element] = Wiki.elements[data['element']] if data['element'].present?

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

        # Uncap status
        suggestions[:flb] = Wiki.boolean.fetch(data['5star'], false) if data['5star'].present?
        suggestions[:ulb] = data['max_evo'].to_i == 6 if data['max_evo'].present?

        # Dates
        suggestions[:release_date] = parse_date(data['release_date']) if data['release_date'].present?
        suggestions[:flb_date] = parse_date(data['5star_date']) if data['5star_date'].present?
        suggestions[:ulb_date] = parse_date(data['6star_date']) if data['6star_date'].present?

        # External links
        suggestions[:gamewith] = data['link_gamewith'] if data['link_gamewith'].present?
        suggestions[:kamigame] = data['link_kamigame'] if data['link_kamigame'].present?

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

        # Element
        suggestions[:element] = Wiki.elements[data['element']] if data['element'].present?

        # Proficiency (weapon type)
        suggestions[:proficiency] = Wiki.proficiencies[data['type']] if data['type'].present?

        # Stats
        suggestions[:min_hp] = data['min_hp'].to_i if data['min_hp'].present?
        suggestions[:max_hp] = data['max_hp'].to_i if data['max_hp'].present?
        suggestions[:max_hp_flb] = data['flb_hp'].to_i if data['flb_hp'].present?
        suggestions[:min_atk] = data['min_atk'].to_i if data['min_atk'].present?
        suggestions[:max_atk] = data['max_atk'].to_i if data['max_atk'].present?
        suggestions[:max_atk_flb] = data['flb_atk'].to_i if data['flb_atk'].present?

        # Uncap status
        suggestions[:flb] = Wiki.boolean.fetch(data['4star'], false) if data['4star'].present?
        suggestions[:ulb] = Wiki.boolean.fetch(data['5star'], false) if data['5star'].present?

        # Dates
        suggestions[:release_date] = parse_date(data['release_date']) if data['release_date'].present?
        suggestions[:flb_date] = parse_date(data['4star_date']) if data['4star_date'].present?
        suggestions[:ulb_date] = parse_date(data['5star_date']) if data['5star_date'].present?

        # External links
        suggestions[:gamewith] = data['link_gamewith'] if data['link_gamewith'].present?
        suggestions[:kamigame] = data['link_kamigame'] if data['link_kamigame'].present?

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

        # Element
        suggestions[:element] = Wiki.elements[data['element']] if data['element'].present?

        # Stats
        suggestions[:min_hp] = data['min_hp'].to_i if data['min_hp'].present?
        suggestions[:max_hp] = data['max_hp'].to_i if data['max_hp'].present?
        suggestions[:max_hp_flb] = data['flb_hp'].to_i if data['flb_hp'].present?
        suggestions[:min_atk] = data['min_atk'].to_i if data['min_atk'].present?
        suggestions[:max_atk] = data['max_atk'].to_i if data['max_atk'].present?
        suggestions[:max_atk_flb] = data['flb_atk'].to_i if data['flb_atk'].present?

        # Uncap status
        suggestions[:flb] = Wiki.boolean.fetch(data['4star'], false) if data['4star'].present?
        suggestions[:ulb] = Wiki.boolean.fetch(data['5star'], false) if data['5star'].present?

        # Sub-aura
        suggestions[:subaura] = Wiki.boolean.fetch(data['subaura'], false) if data['subaura'].present?

        # Dates
        suggestions[:release_date] = parse_date(data['release_date']) if data['release_date'].present?
        suggestions[:flb_date] = parse_date(data['4star_date']) if data['4star_date'].present?
        suggestions[:ulb_date] = parse_date(data['5star_date']) if data['5star_date'].present?

        # External links
        suggestions[:gamewith] = data['link_gamewith'] if data['link_gamewith'].present?
        suggestions[:kamigame] = data['link_kamigame'] if data['link_kamigame'].present?

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
    end
  end
end
