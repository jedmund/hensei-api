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

          # Skip unresolved template-parameter placeholders. These only appear
          # when parsing a Template: definition (e.g. Weapon/Common/Illustrious),
          # never in real page values. Covers both empty defaults ({{{x|}}}) and
          # nested defaults ({{{x|{{{y|}}}}}}) — the latter slip past a
          # |}}}-anchored match and would otherwise overwrite real page values.
          next if value =~ /\A\{\{\{.*\}\}\}\z/

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

      # Extracts weapon skill data from all 4 skill slots, including every
      # uncap/transcendence version tier of each slot.
      #
      # For each slot, the base entry (s{n}_*) plus any suffixed version entries
      # (s{n}_4s_*, s{n}_5s_*, …) are collected. The suffix is only an
      # enumeration marker — the tier (base/FLB/ULB/T1–T5) is derived from each
      # entry's unlock LEVEL (see #tier_for). The charge attack (ougi) is NOT a
      # weapon skill and is never collected here.
      #
      # Returns an array of { position:, versions: [...] }, one per occupied slot.
      def extract_weapon_skills(hash)
        (1..4).filter_map do |slot|
          versions = discover_skill_versions(hash, slot)
          next if versions.empty?

          { position: slot - 1, versions: versions }
        end
      end

      # Collects every version entry for a slot (base + s{n}_<k>s_* entries),
      # orders them ascending by unlock level, and assigns a 0-based ordinal.
      def discover_skill_versions(hash, slot)
        suffixes = []
        suffixes << nil if hash["s#{slot}_name"].present?
        hash.each_key do |key|
          next unless key.to_s =~ /\As#{slot}_(\d+s)_name\z/
          next unless hash[key].present?

          suffixes << Regexp.last_match(1)
        end

        suffixes.uniq
                .filter_map { |suffix| build_skill_entry(hash, slot, suffix: suffix) }
                .sort_by { |entry| entry[:unlock_level] || 0 }
                .each_with_index
                .map { |entry, idx| entry.merge(ordinal: idx) }
      end

      # Maps a skill's unlock LEVEL to its uncap/transcendence tier.
      #   nil / ≤100 → base/MLB (min_uncap 3) · 150 → FLB (4) · 200 → ULB (5)
      #   210–250    → ULB + Transcendence stage (level−200)/10
      def tier_for(level)
        return { min_uncap: 3, transcendence_stage: 0 } if level.nil?

        lvl = level.to_i
        return { min_uncap: 3, transcendence_stage: 0 } if lvl <= 100
        return { min_uncap: 4, transcendence_stage: 0 } if lvl <= 150
        return { min_uncap: 5, transcendence_stage: 0 } if lvl <= 200

        { min_uncap: 5, transcendence_stage: ((lvl - 200) / 10.0).ceil.clamp(1, 5) }
      end

      # Builds a single skill version entry from wiki fields for a given suffix
      # (nil = base, "4s"/"5s"/… = a later version tier).
      def build_skill_entry(hash, slot, suffix: nil)
        prefix    = suffix ? "s#{slot}_#{suffix}" : "s#{slot}"
        en_prefix = suffix ? "ens#{slot}_#{suffix}" : "ens#{slot}"

        raw_name = hash["#{prefix}_name"]
        return nil unless raw_name.present?

        # Clean wiki template syntax and HTML comments from skill name
        name = raw_name.gsub(/\{\{WeaponSkillMod\|[^}]+\}\}\s*/, '').gsub(/<!--.*?-->/, '').strip

        # Description: prefer English-specific field, fall back to generic
        description = hash["#{en_prefix}_desc"].presence || hash["#{prefix}_desc"]

        icon = hash["#{prefix}_icon"]
        unlock_level = hash["#{prefix}_lvl"].presence&.to_i

        # Parse the raw name (with template) for structured components
        parsed = Granblue::Parsers::WeaponSkillParser.parse(raw_name)
        tier = tier_for(unlock_level)

        # Normalize element-variant modifiers to their base ("Strike: Fire" → "Strike").
        modifier = parsed[:modifier]
        modifier = modifier.sub(/:\s*(Fire|Water|Earth|Wind|Light|Dark)\z/, "") if modifier

        # Size: the description states it ("Big boost to …") — the ground truth (see
        # docs/damage/08). A "big" skill named with a II numeral is the rebalanced
        # big_ii tier. Icon/aura are fallbacks for the rare sized skill whose
        # description omits the keyword (mostly genuinely sizeless skills).
        series = parsed[:series]
        size = size_from_description(description)
        size = "big_ii" if size == "big" && raw_name =~ /\bII\b/ && raw_name !~ /\bIII\b/
        if size.nil? || series.nil?
          if (derived = Granblue::Parsers::WeaponSkillParser.derive_from_icon(modifier, icon))
            size ||= derived[:size]
            series ||= derived[:series]
          end
        end
        size ||= parsed[:size] # name numeral as a last resort

        {
          name_en: name,
          description_en: description,
          icon: icon,
          unlock_level: unlock_level,
          min_uncap: tier[:min_uncap],
          transcendence_stage: tier[:transcendence_stage],
          main_hand_only: description.to_s.match?(/when main weapon/i),
          mc_only: description.to_s.match?(/\(mc only\)/i),
          modifier: modifier,
          series: series,
          size: size,
          aura: parsed[:aura]
        }
      end

      SIZE_KEYWORD = /\b(unworldly|massive|big|medium|small)\b/i

      # The size a weapon-skill description states ("Big boost to …"). nil when the
      # description has no size word (genuinely sizeless skills, or template-form).
      def size_from_description(description)
        return nil if description.blank?

        m = description.match(SIZE_KEYWORD) or return nil
        m[1].downcase
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
      #
      # Each slot becomes one WeaponSkill (slot identity); each version tier
      # becomes a WeaponSkillVersion pointing at its own Skill catalog record
      # (the canonical name/description holder). Removes slots and versions no
      # longer present in the wiki data.
      #
      # @param skill_data [Array<Hash>] from extract_weapon_skills
      # @return [Array<WeaponSkill>] persisted slot records
      def persist_skills(skill_data)
        return [] unless @weapon && skill_data.present?

        occupied_positions = []
        persisted = skill_data.filter_map do |slot|
          next if slot[:versions].blank?

          occupied_positions << slot[:position]
          persist_single_skill(slot)
        end

        # Remove slots no longer present in wiki data (cascades to their versions)
        @weapon.weapon_skills.where.not(position: occupied_positions).destroy_all

        persisted
      end

      # Persists one skill slot and its ordered version tiers.
      #
      # @param slot [Hash] { position:, versions: [entry, ...] } from extract_weapon_skills
      # @return [WeaponSkill] persisted slot record
      def persist_single_skill(slot)
        weapon_skill = WeaponSkill.find_or_create_by!(
          weapon_granblue_id: @weapon.granblue_id,
          position: slot[:position]
        )

        seen_ordinals = []
        slot[:versions].each do |entry|
          # Canonical content lives on the shared Skill catalog (deduped by name).
          skill = Skill.find_or_initialize_by(name_en: entry[:name_en], skill_type: :weapon)
          skill.description_en = entry[:description_en] if entry[:description_en].present?
          skill.save!

          version = weapon_skill.weapon_skill_versions.find_or_initialize_by(ordinal: entry[:ordinal])
          version.skill = skill
          # Only store standard modifiers that have WeaponSkillDatum entries;
          # weapon-specific/unique modifiers get nil.
          modifier = entry[:modifier]
          version.skill_modifier = WeaponSkillVersion::VALID_MODIFIERS.include?(modifier) ? modifier : nil
          version.skill_series = entry[:series]
          # Fall back to the canonical (deduped) skill description when this
          # version's own description was empty (a sibling version populated it).
          version.skill_size = entry[:size] || size_from_description(skill.description_en)
          version.unlock_level = entry[:unlock_level]
          version.min_uncap = entry[:min_uncap]
          version.transcendence_stage = entry[:transcendence_stage]
          version.icon = entry[:icon]
          version.main_hand_only = entry[:main_hand_only]
          version.mc_only = entry[:mc_only]
          version.scales_with_skill_level = scales_with_skill_level?(version)
          version.save!

          seen_ordinals << entry[:ordinal]

          next unless @debug
          ap "  Skill #{slot[:position]} v#{entry[:ordinal]} " \
             "(u#{entry[:min_uncap]}/t#{entry[:transcendence_stage]} lvl#{entry[:unlock_level]}): " \
             "#{entry[:name_en]} (#{entry[:series]} #{entry[:modifier]} #{entry[:size]})"
        end

        # Remove stale version tiers (e.g. a tier removed from the wiki)
        weapon_skill.weapon_skill_versions.where.not(ordinal: seen_ordinals).destroy_all

        weapon_skill
      end

      # A version scales with skill level when it maps to a recognized standard
      # grid modifier (one of WeaponSkillVersion::VALID_MODIFIERS, already
      # filtered in persist). Unique/fixed-effect skills have a nil modifier and
      # do not scale.
      def scales_with_skill_level?(version)
        version.skill_modifier.present? && version.weapon_skill_data.exists?
      end

      # Process-wide cache of fetched wikitext, keyed by page title.
      def self.page_cache
        @page_cache ||= {}
      end

      # Fetches a wiki page, served from the process-wide cache on repeat
      # (templates and shared base pages recur across many weapons).
      def fetch_wiki_page(page)
        self.class.page_cache[page] ||= @wiki.fetch(page)
      end

      def fetch_template(name)
        fetch_wiki_page("Template:#{name}")
      end

      # Resolves the wikitext that actually contains a weapon's skill fields.
      # Most pages inline them, but two kinds don't:
      #   - "Mk II"/rebuild weapons whose page is a transclusion of a base
      #     weapon ({{:Base Weapon}}) — skills live on the base page.
      #   - recruitable-character weapons whose wiki_en points at the character
      #     page — the weapon data is on the disambiguated "<name> (Weapon)" page
      #     (named in the {{About|...|the weapon|<page>}} hatnote).
      def skill_source_text(wiki_raw)
        if (transclusion = wiki_raw[/\A\s*\{\{:([^|}\n]+)/, 1])
          return fetch_wiki_page(transclusion.strip)
        end

        if wiki_raw =~ /\A\s*\{\{(?:About|Character|CharacterTabs)\b/i
          page = wiki_raw[/\{\{About\|[^}]*?\|\s*the weapon\s*\|\s*([^}|]+)\}\}/i, 1]&.strip
          page = "#{@weapon.name_en} (Weapon)" if page.blank?
          return fetch_wiki_page(page)
        end

        wiki_raw
      end

      # Parses weapon skills from stored wiki_raw and persists them.
      # Can be called independently without fetching from the wiki.
      #
      # @return [Array<WeaponSkill>] persisted records, or empty array
      def persist_skills_from_wiki_raw
        return [] unless @weapon&.wiki_raw.present?

        extracted = parse_string(skill_source_text(@weapon.wiki_raw))

        # Merge template data if referenced. Templates are shared across many
        # weapons and immutable during a run, so cache fetches to avoid
        # re-hitting the wiki ~1 time per weapon for the same ~20 templates.
        unless extracted[:template].nil?
          extracted.merge!(parse_string(fetch_template(extracted[:template])))
        end

        skill_data = extract_weapon_skills(extracted)
        persist_skills(skill_data)
      rescue StandardError => e
        Rails.logger.error "[WEAPON_SKILLS] Error parsing skills for #{@weapon&.granblue_id}: #{e.message}"
        []
      end
      # Public entry point — called by self.persist_all_skills and the rake task.
      public :persist_skills_from_wiki_raw

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
