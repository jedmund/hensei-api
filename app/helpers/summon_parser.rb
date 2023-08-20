# frozen_string_literal: true

require 'pry'

# SummonParser parses summon data from gbf.wiki
class SummonParser
  attr_reader :granblue_id

  def initialize(granblue_id: String, debug: false)
    @summon = Summon.find_by(granblue_id: granblue_id)
    @wiki = GranblueWiki.new(debug: debug)
    @debug = debug || false
  end

  # Fetches using @wiki and then processes the response
  # Returns true if successful, false if not
  # Raises an exception if something went wrong
  def fetch(name = nil, save: false)
    response = fetch_wiki_info(name)
    return false if response.nil?

    if response.starts_with?('#REDIRECT')
      # Fetch the string inside of [[]]
      redirect = response[/\[\[(.*?)\]\]/m, 1]
      fetch(redirect, save: save)
    else
      # return response if response[:error]
      handle_fetch_success(response, save)
    end
  end

  private

  # Handle the response from the wiki if the response is successful
  # If the save flag is set, it will persist the data to the database
  def handle_fetch_success(response, save)
    ap "#{@summon.granblue_id}: Successfully fetched info for #{@summon.wiki_en}" if @debug

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
  def fetch_wiki_info(name = nil)
    @wiki.fetch(name || @summon.wiki_en)
  rescue WikiError => e
    ap e
    # ap "There was an error fetching #{e.page}: #{e.message}" if @debug
    {
      error: {
        name: @summon.wiki_en,
        granblue_id: @summon.granblue_id
      }
    }
  end

  # Iterates over all summons in the database and fetches their data
  # If the save flag is set, data is saved to the database
  # If the overwrite flag is set, data is fetched even if it already exists
  # If the debug flag is set, additional information is printed to the console
  def self.fetch_all(save: false, overwrite: false, debug: false, start: nil)
    errors = []

    summons = Summon.all.order(:granblue_id)

    start_index = start.nil? ? 0 : summons.index { |w| w.granblue_id == start }
    count = summons.drop(start_index).count

    # ap "Start index: #{start_index}"

    summons.drop(start_index).each_with_index do |w, i|
      percentage = ((i + 1) / count.to_f * 100).round(2)
      ap "#{percentage}%: Fetching #{w.wiki_en}... (#{i + 1}/#{count})" if debug
      next unless w.release_date.nil? || overwrite

      begin
        SummonParser.new(granblue_id: w.granblue_id,
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
      summon = Summon.find_by(granblue_id: id)
      percentage = ((i + 1) / count.to_f * 100).round(2)
      ap "#{percentage}%: Fetching #{summon.wiki_en}... (#{i + 1}/#{count})" if debug
      next unless summon.release_date.nil? || overwrite

      begin
        SummonParser.new(granblue_id: summon.granblue_id,
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

        if substr.start_with?('Summon')
          ap "--> Found template: #{substr}" if @debug

          substr = substr.split('|').first
          data[:template] = substr if substr != 'Summon'
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
    info[:ulb] = hash['evo_max'].to_i >= 5
    info[:xlb] = hash['evo_max'].to_i == 6

    info[:rarity] = rarity_from_hash(hash['rarity'])
    info[:series] = hash['series']
    info[:obtain] = hash['obtain']

    info[:hp] = {
      min_hp: hash['hp1'].to_i,
      max_hp: hash['hp2'].to_i,
      max_hp_flb: hash['hp3'].to_i,
      max_hp_ulb: hash['hp4'].to_i.zero? ? nil : hash['hp4'].to_i,
      max_hp_xlb: hash['hp5'].to_i.zero? ? nil : hash['hp5'].to_i
    }

    info[:atk] = {
      min_atk: hash['atk1'].to_i,
      max_atk: hash['atk2'].to_i,
      max_atk_flb: hash['atk3'].to_i,
      max_atk_ulb: hash['atk4'].to_i.zero? ? nil : hash['atk4'].to_i,
      max_atk_xlb: hash['atk5'].to_i.zero? ? nil : hash['atk5'].to_i
    }

    info[:dates] = {
      release_date: parse_date(hash['release_date']),
      flb_date: parse_date(hash['4star_date']),
      ulb_date: parse_date(hash['5star_date']),
      xlb_date: parse_date(hash['6star_date'])
    }

    info[:links] = {
      wiki: { en: hash['name'], ja: hash['link_jpwiki'] },
      gamewith: hash['link_gamewith'],
      kamigame: hash['link_kamigame']
    }

    {
      info: info.compact
      # skills: skills.compact
    }
  end

  # Saves select fields to the database
  def persist(hash)
    @summon.release_date = hash[:dates][:release_date]
    @summon.flb_date = hash[:dates][:flb_date] if hash[:dates].key?(:flb_date)
    @summon.ulb_date = hash[:dates][:ulb_date] if hash[:dates].key?(:ulb_date)

    @summon.wiki_ja = hash[:links][:wiki][:ja] if hash[:links].key?(:wiki) && hash[:links][:wiki].key?(:ja)
    @summon.gamewith = hash[:links][:gamewith] if hash[:links].key?(:gamewith)
    @summon.kamigame = hash[:links][:kamigame] if hash[:links].key?(:kamigame)

    if @summon.save
      ap "#{@summon.granblue_id}: Successfully saved info for #{@summon.wiki_en}" if @debug
      puts
      true
    end

    false
  end

  # Converts rarities from a string to a hash
  def rarity_from_hash(string)
    string ? GranblueWiki.rarities[string.upcase] : nil
  end

  # Parses a date string into a Date object
  def parse_date(date_str)
    Date.parse(date_str) unless date_str.blank?
  end
end
