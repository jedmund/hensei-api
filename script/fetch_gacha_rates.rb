#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches the game's current draw banner and its published rates, and sends
# them to the API (POST /gacha/banners). Plain Ruby with no gems, so it runs
# anywhere on a schedule, e.g. hourly from cron:
#
#   0 * * * * cd hensei-api && ruby script/fetch_gacha_rates.rb
#
# It remembers when the uploaded banner ends and doesn't contact the game
# until then, so most scheduled runs make no requests. After the banner ends,
# each run checks the game until the next banner is listed.
#
# It signs in as a spare game account with that account's cookies. To seed
# them, sign the account in to the game in a browser, copy the Cookie request
# header of any game.granbluefantasy.jp request from the Network panel, and run:
#
#   pbpaste | ruby script/fetch_gacha_rates.rb --import-cookies
#
# The cookie file is kept up to date from the game's responses. When the game
# signs the account out, the run fails, and alerts if a webhook is set.
#
# Environment:
#   GBF_UID              the spare account's user id (in the game's request URLs)
#   GBF_COOKIE_FILE      the cookie file (default: tmp/gbf-cookies.json)
#   GACHA_RATES_URL      the API endpoint, e.g. https://api.granblue.team/v1/gacha/banners
#   GACHA_RATES_TOKEN    the API's GACHA_RATES_TOKEN
#   GACHA_ALERT_WEBHOOK  optional Discord webhook for failures
#
# Options: --force checks the game and uploads even if the banner hasn't ended
# or changed; --dry-run prints the payload instead of uploading it.

require 'date'
require 'json'
require 'net/http'
require 'time'
require 'uri'

class GachaRatesFetcher
  class SignedOut < StandardError; end

  GAME = URI('https://game.granbluefantasy.jp/')
  # "2026/10/9 19:00" in Japanese
  JAPANESE_TIME = %r{\A(?<year>\d{4})/(?<month>\d{1,2})/(?<day>\d{1,2}) (?<hour>\d{1,2}):(?<minute>\d{2})\z}
  # "7 p.m., Oct 9, 2026 (JST)" or "6:59 p.m., Oct 12, 2026 (JST)" in English
  ENGLISH_TIME = /\A(?<hour>\d{1,2})(?::(?<minute>\d{2}))? (?<half>[ap])\.m\., (?<month>[A-Z][a-z]+)\.? (?<day>\d{1,2}), (?<year>\d{4}) \(JST\)\z/
  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) ' \
               'Chrome/141.0.0.0 Safari/537.36'

  def initialize(env = ENV, force: false, dry_run: false)
    @uid = env['GBF_UID'].to_s
    @cookie_file = env.fetch('GBF_COOKIE_FILE', File.expand_path('../tmp/gbf-cookies.json', __dir__))
    @state_file = "#{@cookie_file.delete_suffix('.json')}-state.json"
    @api = env['GACHA_RATES_URL']
    @token = env['GACHA_RATES_TOKEN']
    @webhook = env['GACHA_ALERT_WEBHOOK']
    @force = force
    @dry_run = dry_run
  end

  def import_cookies(header)
    pairs = header.to_s.sub(/\A\s*cookie:\s*/i, '').split(';').filter_map do |pair|
      name, value = pair.strip.split('=', 2)
      [name, value] if name && !name.empty? && value
    end
    abort 'No cookies found in the input' if pairs.empty?

    # A name can repeat across domains; the game's own copy is kept
    @cookies = pairs.uniq(&:first).to_h
    save_cookies
    puts "Saved #{@cookies.size} cookies to #{@cookie_file}"
  end

  def run
    abort 'Set GBF_UID to the spare account\'s user id' unless @uid.match?(/\A\d+\z/)
    abort 'Set GACHA_RATES_URL and GACHA_RATES_TOKEN' unless @dry_run || (@api && @token)

    state = load_state
    ends_at = state['ends_at'] && Time.iso8601(state['ends_at'])
    if !@force && ends_at && Time.now < ends_at
      puts "Banner #{state['game_id']} runs until #{ends_at.iso8601}"
      return
    end

    @cookies = load_cookies
    version = game_version
    banner = current_banner(version)
    if !@force && state['game_id'] == banner['id']
      # The game hasn't listed the next banner yet, or extended this one
      save_state('game_id' => banner['id'], 'ends_at' => banner_end(banner)&.iso8601)
      puts "Banner #{banner['id']} is unchanged"
      return
    end

    tabs = %w[1 2].to_h { |tab| [tab, rates(version, banner['id'], tab)] }
    payload = { 'banner' => banner.slice('id', 'name', 'times', 'service_start', 'service_end'), 'tabs' => tabs }
    return puts(JSON.pretty_generate(payload)) if @dry_run

    result = upload(payload)
    save_state('game_id' => banner['id'], 'ends_at' => banner_end(banner)&.iso8601)
    puts "Uploaded banner #{result['game_id']}: #{result['items']} items, #{result['unmatched']} not in the catalogue"
    alert("Banner #{result['game_id']} has #{result['unmatched']} items missing from the catalogue") if result['unmatched'].to_i.positive?
  rescue SignedOut => e
    fail_with("The spare account is signed out of the game (#{e.message}); seed its cookies again")
  rescue StandardError => e
    fail_with("#{e.class}: #{e.message}")
  ensure
    save_cookies if @cookies
  end

  private

  # The game rejects requests without its current version, which changes at
  # maintenance; its home page carries it
  def game_version
    html = get(GAME, html: true)
    version = html[/"version":\s*"(\d+)"/, 1]
    raise SignedOut, 'no game version on the home page' unless version

    version
  end

  # The 10-part legend banner, or the first one listed
  def current_banner(version)
    list = get_json('gacha/list', version)
    lineup = list.dig('legend', 'lineup')
    raise 'No legend banners listed' unless lineup.is_a?(Array) && !lineup.empty?

    lineup.find { |entry| entry['times'].to_s == '10' } || lineup.first
  end

  def rates(version, id, tab)
    raise "Invalid banner id #{id.inspect}" unless id.to_s.match?(/\A\d+\z/)

    get_json("gacha/provision_ratio/legend/#{id}/#{tab}", version)
  end

  # When the banner stops being drawn: a minute after its listed end, which is
  # given to the minute ("18:59"). Nil if the time can't be read, so the next
  # run checks the game again.
  def banner_end(banner)
    text = banner['service_end'].to_s
    parts = text.match(JAPANESE_TIME) || text.match(ENGLISH_TIME)
    unless parts
      warn "Couldn't read the banner's end time: #{text.inspect}"
      return
    end

    hour = parts[:hour].to_i
    hour = (hour % 12) + (parts[:half] == 'p' ? 12 : 0) if parts.names.include?('half')
    month = parts[:month].match?(/\A\d+\z/) ? parts[:month].to_i : Date::ABBR_MONTHNAMES.index(parts[:month][0, 3])
    Time.new(parts[:year].to_i, month, parts[:day].to_i, hour, parts[:minute].to_i, 0, '+09:00') + 60
  rescue ArgumentError, TypeError
    warn "Couldn't read the banner's end time: #{text.inspect}"
    nil
  end

  def get_json(path, version)
    now = (Time.now.to_f * 1000).to_i
    uri = URI.join(GAME, "#{path}?_=#{now}&t=#{now}&uid=#{@uid}")
    body = get(uri, headers: { 'X-Version' => version, 'X-Requested-With' => 'XMLHttpRequest',
                               'Accept' => 'application/json, text/javascript, */*; q=0.01' })
    JSON.parse(body)
  rescue JSON::ParserError
    raise SignedOut, "#{path} didn't return JSON"
  end

  def get(uri, headers: {}, html: false)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = USER_AGENT
    request['Referer'] = GAME.to_s
    request['Accept'] = 'text/html' if html
    request['Cookie'] = @cookies.map { |name, value| "#{name}=#{value}" }.join('; ')
    headers.each { |name, value| request[name] = value }
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.request(request)
    end
    keep_cookies(response)
    raise SignedOut, "#{uri.path} redirected to #{response['Location']}" if response.is_a?(Net::HTTPRedirection)
    raise "#{uri.path} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body.to_s.dup.force_encoding('UTF-8')
  end

  # Keeps cookies the game sets, and drops ones it expires
  def keep_cookies(response)
    Array(response.get_fields('Set-Cookie')).each do |header|
      pair, *attributes = header.split(';').map(&:strip)
      name, value = pair.split('=', 2)
      next unless name && value

      expired = attributes.any? do |attribute|
        key, setting = attribute.split('=', 2)
        (key.casecmp?('max-age') && setting.to_i <= 0) || (key.casecmp?('expires') && past?(setting))
      end
      expired ? @cookies.delete(name) : @cookies[name] = value
    end
  end

  def past?(date)
    Time.httpdate(date.to_s) <= Time.now
  rescue ArgumentError
    false
  end

  def upload(payload)
    uri = URI(@api)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(payload)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15,
                                                   read_timeout: 60) { |http| http.request(request) }
    raise "The API returned #{response.code}: #{response.body.to_s[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def load_cookies
    raise SignedOut, "no cookie file at #{@cookie_file}" unless File.exist?(@cookie_file)

    JSON.parse(File.read(@cookie_file))
  end

  def save_cookies
    File.write(@cookie_file, JSON.generate(@cookies))
    File.chmod(0o600, @cookie_file)
  end

  def load_state
    File.exist?(@state_file) ? JSON.parse(File.read(@state_file)) : {}
  end

  def save_state(state)
    File.write(@state_file, JSON.generate(state))
  end

  def fail_with(message)
    warn message
    alert(message)
    exit 1
  end

  def alert(message)
    return unless @webhook

    uri = URI(@webhook)
    Net::HTTP.post(uri, JSON.generate(content: "Gacha rates: #{message}"), 'Content-Type' => 'application/json')
  rescue StandardError => e
    warn "Couldn't send the alert: #{e.class}"
  end
end

if $PROGRAM_NAME == __FILE__
  fetcher = GachaRatesFetcher.new(force: ARGV.include?('--force'), dry_run: ARGV.include?('--dry-run'))
  ARGV.include?('--import-cookies') ? fetcher.import_cookies($stdin.read) : fetcher.run
end
