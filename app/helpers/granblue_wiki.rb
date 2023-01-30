# frozen_string_literal: true

require 'rubygems'
require 'httparty'
require 'strscan'
require 'pry'

# GranblueWiki fetches and parses data from gbf.wiki
class GranblueWiki
  URL = 'https://gbf.wiki/api.php'

  PROFICIENCY_MAP = {
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
  }

  ELEMENT_MAP = {
    'Wind' => 1,
    'Fire' => 2,
    'Water' => 3,
    'Earth' => 4,
    'Dark' => 5,
    'Light' => 6
  }

  RARITY_MAP = {
    'R' => 1,
    'SR' => 2,
    'SSR' => 3
  }

  RACE_MAP = {
    'Other' => 0,
    'Human' => 1,
    'Erune' => 2,
    'Draph' => 3,
    'Harvin' => 4,
    'Primal' => 5
  }

  GENDER_MAP = {
    'o' => 0,
    'm' => 1,
    'f' => 2,
    'mf' => 3
  }

  BOOLEAN_MAP = {
    'yes' => true,
    'no' => false
  }

  def fetch(page)
    query_params = params(page).map do |key, value|
      "#{key}=#{value}"
    end.join('&')

    destination = "#{URL}?#{query_params}"
    response = HTTParty.get(destination)

    response['parse']['wikitext']['*']
  end

  def save_characters(characters)
    success = 0
    characters.each do |chara|
      success += 1 if parse(chara)
    end
    puts "Saved #{success} characters to the database"
  end
  def parse(page)
    parsed = parse_string(fetch(page))
    info = extract_chara_info(parsed)
    create_character(info)

    # abilities = extract_abilities(parsed)
    # ougis = extract_ougis(parsed)

    # ap abilities.merge(ougis)
  end

  def extract_chara_info(hash)
    info = Hash.new

    info[:name] = {
      en: hash['name'],
      ja: hash['jpname']
    }
    info[:id] = hash['id']
    info[:charid] = hash['charid'].scan(/\b\d{4}\b/)

    info[:flb] = BOOLEAN_MAP.fetch(hash['5star'], false)
    info[:ulb] = true if hash['max_evo'].to_i == 6

    info[:rarity] = RARITY_MAP.fetch(hash['rarity'], 0)
    info[:element] = ELEMENT_MAP.fetch(hash['element'], 0)
    info[:gender] = GENDER_MAP.fetch(hash['gender'], 0)

    profs = hash['weapon'].to_s.split(',')
    proficiencies = profs.map.with_index do |prof, i|
      { "proficiency#{i + 1}" => PROFICIENCY_MAP[prof] }
    end
    info[:proficiencies] = proficiencies.reduce({}, :merge)

    races = hash['race'].to_s.split(',')
    mapped_races = races.map.with_index do |race, i|
      { "race#{i + 1}" => RACE_MAP[race] }
    end
    info[:races] = mapped_races.reduce({}, :merge)

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

    { 'info' => info.compact }
  end

  def create_character(hash)
    info = hash['info']

    c = Character.new
    c.granblue_id = info[:id]
    c.character_id = info[:charid]
    c.name_en = info[:name][:en]
    c.name_jp = info[:name][:ja]
    c.flb = info[:flb]
    c.ulb = info[:ulb] if info.key?(:ulb)
    c.rarity = info[:rarity]
    c.element = info[:element]
    c.gender = info[:gender]
    c.race1 = info[:races]['race1']
    c.race2 = info[:races]['race2'] if info[:races].key?('race2')
    c.proficiency1 = info[:proficiencies]['proficiency1']
    c.proficiency2 = info[:proficiencies]['proficiency2'] if info[:proficiencies].key?('proficiency2')
    c.min_hp = info[:hp][:min_hp]
    c.max_hp = info[:hp][:max_hp]
    c.max_hp_flb = info[:hp][:max_hp_flb]
    c.min_atk = info[:atk][:min_atk]
    c.max_atk = info[:atk][:max_atk]
    c.max_atk_flb = info[:atk][:max_atk_flb]

    if c.save
      puts "Saved #{c.name_en} (#{c.granblue_id}) to the database"
      true
    end

    false
  end

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

  def parse_string(string)
    # Split the string into lines
    lines = string.split("\n")

    # Initialize an empty hash to store the key/value pairs
    data = {}

    # Iterate over the lines
    good_lines = lines.map do |line|
      line if line[0] == '|' && line.size > 2
    end

    good_lines.compact.each do |line|
      trimmed_line = line[1..]

      # Split the line into key and value by the '=' character
      key, value = trimmed_line.split('=', 2)

      next unless value

      # Strip leading and trailing whitespace from the key and value
      key = key.strip
      value = value.strip

      # Store the key/value pair in the data hash
      data[key] = value
    end

    # Return the data hash
    data
  end

  private

  def params(page)
    {
      action: 'parse',
      format: 'json',
      page: page,
      prop: 'wikitext'
    }
  end
end
