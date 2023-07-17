# frozen_string_literal: true

require 'httparty'

# GranblueWiki fetches and parses data from gbf.wiki
class GranblueWiki
  class_attribute :base_uri

  class_attribute :proficiencies
  class_attribute :elements
  class_attribute :rarities
  class_attribute :genders
  class_attribute :races
  class_attribute :boolean

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

  self.boolean = {
    'yes' => true,
    'no' => false
  }.freeze

  def fetch(page)
    query_params = params(page).map do |key, value|
      "#{key}=#{value}"
    end.join('&')

    destination = "#{base_uri}?#{query_params}"
    response = HTTParty.get(destination)

    handle_response(response, page)
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
    when 404 then puts "Page #{page} not found"
    when 500...600 then puts "Server error: #{response.code}"
    end
  end

  def params(page)
    {
      action: 'parse',
      format: 'json',
      page: page,
      prop: 'wikitext'
    }
  end
end
