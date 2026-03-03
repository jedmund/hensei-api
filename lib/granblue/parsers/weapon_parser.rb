# frozen_string_literal: true

require 'pry'

module Granblue
  module Parsers
    # WeaponParser parses weapon data from gbf.wiki
    class WeaponParser
      attr_reader :granblue_id

      def initialize(granblue_id: String, debug: false)
        @weapon = Weapon.find_by(granblue_id: granblue_id)
        @wiki = Granblue::Parsers::Wiki.new
        @debug = debug || false
      end

      # Fetches using @wiki and then processes the response
      # Returns true if successful, false if not
      # Raises an exception if something went wrong
      def fetch(save: false)
        response = fetch_wiki_info
        return false if response.nil?

        # return response if response[:error]

        handle_fetch_success(response, save)
      end

      private

      # Handle the response from the wiki if the response is successful
      # If the save flag is set, it will persist the data to the database
      def handle_fetch_success(response, save)
        ap "#{@weapon.granblue_id}: Successfully fetched info for #{@weapon.wiki_en}" if @debug
        extracted = parse_string(response)

        unless extracted[:template].nil?
          template = @wiki.fetch("Template:#{extracted[:template]}")
          extracted.merge!(parse_string(template))
        end

        result = parse(extracted)

        if save
          persist(result[:info])
          persist_skills(result[:skills][:skills])
        end

        true
      end

      # Fetches the wiki info from the wiki
      # Returns the response body
      # Raises an exception if something went wrong
      def fetch_wiki_info
        @wiki.fetch(@weapon.wiki_en)
      rescue WikiError => e
        ap e
        # ap "There was an error fetching #{e.page}: #{e.message}" if @debug
        {
          error: {
            name: @weapon.wiki_en,
            granblue_id: @weapon.granblue_id
          }
        }
      end

      # Iterates over all weapons in the database and fetches their data
      # If the save flag is set, data is saved to the database
      # If the overwrite flag is set, data is fetched even if it already exists
      # If the debug flag is set, additional information is printed to the console
      def self.fetch_all(save: false, overwrite: false, debug: false, start: nil)
        errors = []

        weapons = Weapon.all.order(:granblue_id)

        start_index = start.nil? ? 0 : weapons.index { |w| w.granblue_id == start }
        count = weapons.drop(start_index).count

        # ap "Start index: #{start_index}"

        weapons.drop(start_index).each_with_index do |w, i|
          percentage = ((i + 1) / count.to_f * 100).round(2)
          ap "#{percentage}%: Fetching #{w.wiki_en}... (#{i + 1}/#{count})" if debug
          next if w.wiki_en.include?('Element Changed') || w.wiki_en.include?('Awakened')
          next unless w.release_date.nil? || overwrite

          begin
            WeaponParser.new(granblue_id: w.granblue_id,
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
          weapon = Weapon.find_by(granblue_id: id)
          percentage = ((i + 1) / count.to_f * 100).round(2)
          ap "#{percentage}%: Fetching #{weapon.wiki_en}... (#{i + 1}/#{count})" if debug
          next unless weapon.release_date.nil? || overwrite

          begin
            WeaponParser.new(granblue_id: weapon.granblue_id,
                             debug: debug).fetch(save: save)
          rescue WikiError => e
            errors.push(e.page)
          end
        end

        ap 'The following pages were unable to be fetched:'
        ap errors
      end

      # Parses the response string into a hash
      def parse_string(string)
        data = {}
        lines = string.split("\n")
        stop_loop = false

        lines.each do |line|
          next if stop_loop

          if line.include?('Gameplay Notes')
            stop_loop = true
            next
          end

          if line.starts_with?('{{')
            substr = line[2..].strip! || line[2..]

            # All template tags start with {{ so we can skip the first two characters
            disallowed = %w[#vardefine #lsth About]
            next if substr.start_with?(*disallowed)

            if substr.start_with?('Weapon')
              ap "--> Found template: #{substr}" if @debug

              substr = substr.split('|').first
              data[:template] = substr if substr != 'Weapon'
              next
            end
          end

          next unless line[0] == '|' && line.size > 2

          key, value = line[1..].split('=', 2).map(&:strip)

          regex = /\A\{\{\{.*\|\}\}\}\z/
          next if value =~ regex

          data[key] = value if value
        end

        data
      end

      # Parses the hash into a format that can be saved to the database
      def parse(hash)
        info = {}
        skills = {}

        info[:name] = { en: hash['name'], ja: hash['jpname'] }
        info[:flavor] = { en: hash['flavor'], ja: hash['jpflavor'] }
        info[:id] = hash['id']

        info[:flb] = hash['evo_max'].to_i >= 4
        info[:ulb] = hash['evo_max'].to_i == 5

        info[:rarity] = rarity_from_hash(hash['rarity'])
        info[:proficiency] = proficiency_from_hash(hash['weapon'])
        info[:series] = hash['series']
        info[:obtain] = hash['obtain']

        if hash.key?('bullets')
          info[:bullets] = {
            count: hash['bullets'].to_i,
            loadout: [
              bullet_from_hash(hash['bullet1']),
              bullet_from_hash(hash['bullet2']),
              bullet_from_hash(hash['bullet3']),
              bullet_from_hash(hash['bullet4']),
              bullet_from_hash(hash['bullet5']),
              bullet_from_hash(hash['bullet6'])
            ]
          }
        end

        info[:hp] = {
          min_hp: hash['hp1'].to_i,
          max_hp: hash['hp2'].to_i,
          max_hp_flb: hash['hp3'].to_i,
          max_hp_ulb: hash['hp4'].to_i.zero? ? nil : hash['hp4'].to_i
        }

        info[:atk] = {
          min_atk: hash['atk1'].to_i,
          max_atk: hash['atk2'].to_i,
          max_atk_flb: hash['atk3'].to_i,
          max_atk_ulb: hash['atk4'].to_i.zero? ? nil : hash['atk4'].to_i
        }

        info[:dates] = {
          release_date: parse_date(hash['release_date']),
          flb_date: parse_date(hash['4star_date']),
          ulb_date: parse_date(hash['5star_date'])
        }

        info[:links] = {
          wiki: { en: hash['name'], ja: hash['link_jpwiki'] },
          gamewith: hash['link_gamewith'],
          kamigame: hash['link_kamigame']
        }

        info[:promotions] = promotions_from_obtain(hash['obtain'])

        skills[:charge_attack] = {
          name: { en: hash['ougi_name'], ja: hash['jpougi_name'] },
          description: {
            mlb: {
              en: hash['enougi'],
              ja: hash['jpougi']
            },
            flb: {
              en: hash['enougi_4s'],
              ja: hash['jpougi_4s']
            }
          }
        }

        skills[:skills] = extract_weapon_skills(hash)

        {
          info: info.compact,
          skills: skills.compact
        }
      end

      # Extracts weapon skill data from all 3 skill slots, including 4★ upgrades.
      #
      # For each slot, extracts:
      #   - Base skill: s{n}_name, s{n}_desc/ens{n}_desc, s{n}_icon, s{n}_lvl
      #   - 4★ upgrade: s{n}_4s_name, s{n}_4s_desc/ens{n}_4s_desc, s{n}_4s_icon, s{n}_4s_lvl
      #
      # Returns an array of skill hashes, one per occupied slot.
      def extract_weapon_skills(hash)
        (1..3).filter_map do |slot|
          base_name = hash["s#{slot}_name"]
          next unless base_name.present?

          skill = {
            position: slot - 1,
            base: build_skill_entry(hash, slot, upgrade: false),
            upgrade: nil
          }

          # Check for 4★ upgrade
          upgrade_name = hash["s#{slot}_4s_name"]
          skill[:upgrade] = build_skill_entry(hash, slot, upgrade: true) if upgrade_name.present?

          skill
        end
      end

      # Builds a single skill entry (base or upgrade) from wiki fields.
      def build_skill_entry(hash, slot, upgrade: false)
        prefix = upgrade ? "s#{slot}_4s" : "s#{slot}"

        raw_name = hash["#{prefix}_name"]
        return nil unless raw_name.present?

        # Clean wiki template syntax and HTML comments from skill name
        name = raw_name.gsub(/\{\{WeaponSkillMod\|[^}]+\}\}\s*/, '').gsub(/<!--.*?-->/, '').strip

        # Description: prefer English-specific field, fall back to generic
        description = if upgrade
                        hash["ens#{slot}_4s_desc"].presence || hash["#{prefix}_desc"]
                      else
                        hash["ens#{slot}_desc"].presence || hash["#{prefix}_desc"]
                      end

        icon = hash["#{prefix}_icon"]
        unlock_level = hash["#{prefix}_lvl"].presence&.to_i

        # Parse the raw name (with template) for structured components
        parsed = Granblue::Parsers::WeaponSkillParser.parse(raw_name)

        {
          name_en: name,
          description_en: description,
          icon: icon,
          unlock_level: unlock_level,
          modifier: parsed[:modifier],
          series: parsed[:series],
          size: parsed[:size],
          aura: parsed[:aura]
        }
      end

      # Saves select fields to the database
      def persist(hash)
        @weapon.release_date = hash[:dates][:release_date]
        @weapon.flb_date = hash[:dates][:flb_date] if hash[:dates].key?(:flb_date)
        @weapon.ulb_date = hash[:dates][:ulb_date] if hash[:dates].key?(:ulb_date)

        @weapon.wiki_ja = hash[:links][:wiki][:ja] if hash[:links].key?(:wiki) && hash[:links][:wiki].key?(:ja)
        @weapon.gamewith = hash[:links][:gamewith] if hash[:links].key?(:gamewith)
        @weapon.kamigame = hash[:links][:kamigame] if hash[:links].key?(:kamigame)

        @weapon.promotions = hash[:promotions] if hash[:promotions].present?

        if @weapon.save
          ap "#{@weapon.granblue_id}: Successfully saved info for #{@weapon.wiki_en}" if @debug
          puts
          true
        end

        false
      end

      # Persists weapon skills from parsed wiki data to the database.
      # Creates Skill records (shared catalog) and WeaponSkill records (join table).
      #
      # For each skill slot, stores:
      # - Base version at uncap_level 0
      # - 4★ upgrade version at uncap_level 4 (if present)
      # Removes any existing weapon skills for positions no longer present.
      #
      # @param skill_data [Array<Hash>] from extract_weapon_skills
      # @return [Array<WeaponSkill>] persisted records
      def persist_skills(skill_data)
        return [] unless @weapon && skill_data.present?

        persisted = []
        occupied_positions = []

        skill_data.each do |slot|
          next unless slot[:base]

          position = slot[:position]
          occupied_positions << position

          # Always persist the base version (uncap_level: 0)
          persisted << persist_single_skill(slot[:base], position, uncap_level: 0)

          # Persist the 4★ upgrade version (uncap_level: 4) if it exists
          if slot[:upgrade]
            persisted << persist_single_skill(slot[:upgrade], position, uncap_level: 4)
          end
        end

        # Remove weapon skills at positions that no longer exist in wiki data
        @weapon.weapon_skills.where.not(position: occupied_positions).destroy_all

        persisted
      end

      # Persists a single weapon skill entry at a given position and uncap level.
      #
      # @param entry [Hash] skill entry from build_skill_entry
      # @param position [Integer] skill slot index
      # @param uncap_level [Integer] 0 for base, 4 for FLB upgrade
      # @return [WeaponSkill] persisted record
      def persist_single_skill(entry, position, uncap_level:)
        # Find or create the Skill catalog record
        skill = Skill.find_or_initialize_by(
          name_en: entry[:name_en],
          skill_type: :weapon
        )
        skill.description_en = entry[:description_en] if entry[:description_en].present?
        skill.save!

        # Find or initialize the WeaponSkill join record
        weapon_skill = WeaponSkill.find_or_initialize_by(
          weapon_granblue_id: @weapon.granblue_id,
          position: position,
          uncap_level: uncap_level
        )

        weapon_skill.skill = skill
        # Only store standard modifiers that have WeaponSkillDatum entries.
        # Weapon-specific modifiers (from permissive aura matching) get nil.
        modifier = entry[:modifier]
        weapon_skill.skill_modifier = WeaponSkill::VALID_MODIFIERS.include?(modifier) ? modifier : nil
        weapon_skill.skill_series = entry[:series]
        weapon_skill.skill_size = entry[:size]
        weapon_skill.unlock_level = entry[:unlock_level]
        weapon_skill.save!

        ap "  Skill #{position} (uncap #{uncap_level}): #{entry[:name_en]} (#{entry[:series]} #{entry[:modifier]} #{entry[:size]})" if @debug

        weapon_skill
      end

      # Parses weapon skills from stored wiki_raw and persists them.
      # Can be called independently without fetching from the wiki.
      #
      # @return [Array<WeaponSkill>] persisted records, or empty array
      def persist_skills_from_wiki_raw
        return [] unless @weapon&.wiki_raw.present?

        extracted = parse_string(@weapon.wiki_raw)

        # Merge template data if referenced
        unless extracted[:template].nil?
          template_text = @wiki.fetch("Template:#{extracted[:template]}")
          extracted.merge!(parse_string(template_text))
        end

        skill_data = extract_weapon_skills(extracted)
        persist_skills(skill_data)
      rescue StandardError => e
        Rails.logger.error "[WEAPON_SKILLS] Error parsing skills for #{@weapon&.granblue_id}: #{e.message}"
        []
      end

      # Batch process: parse and persist weapon skills for all weapons with wiki_raw data.
      #
      # @param debug [Boolean] print progress
      # @param overwrite [Boolean] re-process weapons that already have skills
      # @return [Hash] { processed: Integer, skipped: Integer, errors: Array<String> }
      def self.persist_all_skills(debug: false, overwrite: false)
        weapons = Weapon.where.not(wiki_raw: [nil, ''])
        weapons = weapons.left_joins(:weapon_skills).where(weapon_skills: { id: nil }) unless overwrite

        total = weapons.count
        errors = []
        processed = 0

        weapons.find_each.with_index do |weapon, i|
          if debug
            percentage = ((i + 1) / total.to_f * 100).round(1)
            ap "#{percentage}%: Processing skills for #{weapon.name_en} (#{weapon.granblue_id})... (#{i + 1}/#{total})"
          end

          parser = new(granblue_id: weapon.granblue_id, debug: debug)
          results = parser.persist_skills_from_wiki_raw

          if results.any?
            processed += 1
          end
        rescue StandardError => e
          errors << "#{weapon.granblue_id}: #{e.message}"
          Rails.logger.error "[WEAPON_SKILLS] Failed for #{weapon.granblue_id}: #{e.message}"
        end

        if debug
          ap "Done. Processed #{processed}/#{total} weapons."
          ap "Errors (#{errors.size}):" if errors.any?
          errors.each { |err| ap "  #{err}" }
        end

        { processed: processed, skipped: total - processed - errors.size, errors: errors }
      end

      # Converts rarities from a string to a hash
      def rarity_from_hash(string)
        string ? Granblue::Parsers::Wiki.rarities[string.upcase] : nil
      end

      # Converts proficiencies from a string to a hash
      def proficiency_from_hash(string)
        Granblue::Parsers::Wiki.proficiencies[string]
      end

      # Converts a bullet type from a string to a hash
      def bullet_from_hash(string)
        string ? Granblue::Parsers::Wiki.bullets[string] : nil
      end

      # Converts wiki obtain field to promotions array
      # @param obtain [String] Comma-separated obtain values like "premium,gala,flash"
      # @return [Array<Integer>] Array of promotion IDs
      def promotions_from_obtain(obtain)
        return [] if obtain.blank?

        obtain.downcase.split(',').map(&:strip).filter_map do |value|
          Granblue::Parsers::Wiki.promotions[value]
        end.uniq.sort
      end

      # Parses a date string into a Date object
      def parse_date(date_str)
        Date.parse(date_str) unless date_str.blank?
      end
    end
  end
end
