# frozen_string_literal: true

require 'rubygems'
require 'httparty'
require 'strscan'
require 'pry'

# GranblueWiki fetches and parses data from gbf.wiki
class GranblueWiki
  URL = 'https://gbf.wiki/api.php'

  def fetch(page)
    query_params = params(page).map do |key, value|
      "#{key}=#{value}"
    end.join('&')

    destination = "#{URL}?#{query_params}"
    response = HTTParty.get(destination)

    response['parse']['wikitext']['*']
  end

  def parse(page)
    parsed = parse_string(fetch(page))

    abilities = extract_abilities(parsed)
    ougis = extract_ougis(parsed)

    ap abilities.merge(ougis)
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
