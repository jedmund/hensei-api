# frozen_string_literal: true

require 'pry'

# WeaponParser parses weapon data from gbf.wiki
class WeaponParser
  attr_reader :granblue_id

  def initialize(granblue_id: String, debug: false)
    @weapon = Weapon.find_by(granblue_id: granblue_id)
    @wiki = GranblueWiki.new(debug: debug)
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

    info, skills = parse(extracted)

    # ap info
    # ap skills

    persist(info[:info]) if save
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

    skills[:skills] = [
      {
        name: { en: hash['s1_name'], ja: nil },
        description: { en: hash['ens1_desc'] || hash['s1_desc'], ja: nil }
      },
      {
        name: { en: hash['s2_name'], ja: nil },
        description: { en: hash['ens2_desc'] || hash['s2_desc'], ja: nil }
      },
      {
        name: { en: hash['s3_name'], ja: nil },
        description: { en: hash['ens3_desc'] || hash['s3_desc'], ja: nil }
      }
    ]

    {
      info: info.compact,
      skills: skills.compact
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

    if @weapon.save
      ap "#{@weapon.granblue_id}: Successfully saved info for #{@weapon.wiki_en}" if @debug
      puts
      true
    end

    false
  end

  # Converts rarities from a string to a hash
  def rarity_from_hash(string)
    string ? GranblueWiki.rarities[string.upcase] : nil
  end

  # Converts proficiencies from a string to a hash
  def proficiency_from_hash(string)
    GranblueWiki.proficiencies[string]
  end

  # Converts a bullet type from a string to a hash
  def bullet_from_hash(string)
    string ? GranblueWiki.bullets[string] : nil
  end

  # Parses a date string into a Date object
  def parse_date(date_str)
    Date.parse(date_str) unless date_str.blank?
  end
end
