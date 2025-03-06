# frozen_string_literal: true

class Dataminer
  include HTTParty

  BOT_UID = '39094985'
  GAME_VERSION = '1741068713'

  base_uri 'https://game.granbluefantasy.jp'
  format :json

  HEADERS = {
    'Accept' => 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language' => 'en-US,en;q=0.9',
    'Accept-Encoding' => 'gzip, deflate, br, zstd',
    'Content-Type' => 'application/json',
    'DNT' => '1',
    'Origin' => 'https://game.granbluefantasy.jp',
    'Referer' => 'https://game.granbluefantasy.jp/',
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36',
    'X-Requested-With' => 'XMLHttpRequest'
  }.freeze

  attr_reader :page, :cookies

  def initialize(page:, access_token:, wing:, midship:, t: 'dummy')
    @page = page
    @cookies = {
      access_gbtk: access_token,
      wing: wing,
      t: t,
      midship: midship
    }
  end

  def fetch
    timestamp = Time.now.to_i * 1000
    response = self.class.post(
      "/#{page}?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}",
      headers: HEADERS.merge(
        'Cookie' => format_cookies,
        'X-VERSION' => GAME_VERSION
      )
    )

    raise AuthenticationError if auth_failed?(response)

    response
  end

  def fetch_character(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/npc_detail?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}"
    body = {
      special_token: nil,
      user_id: BOT_UID,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      style: 1,
      character_id: granblue_id
    }

    response = fetch_detail(url, body)
    update_game_data('Character', granblue_id, response) if response
    response
  end

  def fetch_weapon(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/weapon_detail?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}"
    body = {
      special_token: nil,
      user_id: BOT_UID,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      weapon_id: granblue_id
    }

    response = fetch_detail(url, body)
    update_game_data('Weapon', granblue_id, response) if response
    response
  end

  def fetch_summon(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/summon_detail?_=#{timestamp}&t=#{timestamp}&uid=#{BOT_UID}"
    body = {
      special_token: nil,
      user_id: BOT_UID,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      summon_id: granblue_id
    }

    response = fetch_detail(url, body)
    update_game_data('Summon', granblue_id, response) if response
    response
  end

  private

  def format_cookies
    cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
  end

  def auth_failed?(response)
    return true if response.code != 200

    begin
      parsed = JSON.parse(response.body)
      parsed.is_a?(Hash) && parsed['auth_status'] == 'require_auth'
    rescue JSON::ParserError
      true
    end
  end

  def fetch_detail(url, body)
    puts "\n=== Request Details ==="
    puts "URL: #{url}"
    puts 'Headers:'
    puts HEADERS.merge(
      'Cookie' => format_cookies,
      'X-VERSION' => GAME_VERSION
    ).inspect
    puts 'Body:'
    puts body.to_json
    puts '===================='

    response = self.class.post(
      url,
      headers: HEADERS.merge(
        'Cookie' => format_cookies,
        'X-VERSION' => GAME_VERSION
      ),
      body: body.to_json
    )

    puts "\n=== Response Details ==="
    puts "Response code: #{response.code}"
    puts 'Response headers:'
    puts response.headers.inspect
    puts 'Raw response body:'
    puts response.body.inspect
    begin
      puts 'Parsed response body (if JSON):'
      puts JSON.parse(response.body).inspect
    rescue JSON::ParserError => e
      puts "Could not parse as JSON: #{e.message}"
    end
    puts '======================'

    raise AuthenticationError if auth_failed?(response)

    JSON.parse(response.body)
  end

  def update_game_data(model_name, granblue_id, response_data)
    return unless response_data.is_a?(Hash)

    model = Object.const_get(model_name)
    record = model.find_by(granblue_id: granblue_id)

    if record
      record.update(game_raw_en: response_data)
      puts "Updated #{model_name} #{granblue_id}"
    else
      puts "#{model_name} with granblue_id #{granblue_id} not found in database"
    end
  rescue StandardError => e
    puts "Error updating #{model_name} #{granblue_id}: #{e.message}"
  end

  class AuthenticationError < StandardError; end
end
