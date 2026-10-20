# frozen_string_literal: true

class Dataminer
  include HTTParty

  BOT_UID = '39094985'
  GAME_VERSION = '1741068713'
  # Seconds between two requests to the game, at least (the same pace as the wikis).
  MIN_DELAY = 2.0
  LANG_COLUMNS = { 'en' => :game_raw_en, 'jp' => :game_raw_jp, 'ja' => :game_raw_jp }.freeze

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

  attr_reader :page, :cookies, :logger, :debug, :user_id, :game_version, :summary, :delay,
              :remaining_ids

  # The delay to use for a requested value (nil → MIN_DELAY); a shorter one is raised
  # to MIN_DELAY, and warn is called with a note.
  def self.clamp_delay(requested, warn: nil)
    return MIN_DELAY if requested.nil?

    delay = requested.to_f
    return delay if delay >= MIN_DELAY

    warn&.call("Game delay #{delay}s is below the #{MIN_DELAY}s minimum; using #{MIN_DELAY}s.")
    MIN_DELAY
  end

  # user_id and game_version default to the baked-in constants but should be
  # overridden per session: uid is the logged-in account's player id and
  # game_version is the current game build (both change over time).
  # rubocop:disable-next Metrics/ParameterLists
  def initialize(page:, access_token:, wing:, midship:, t: 'dummy',
                 user_id: BOT_UID, game_version: GAME_VERSION, debug: false, delay: MIN_DELAY)
    @page = page
    @cookies = {
      access_gbtk: access_token,
      wing: wing,
      t: t,
      midship: midship
    }
    @user_id = user_id
    @game_version = game_version
    @debug = debug
    @delay = self.class.clamp_delay(delay)
    # Set when a run stopped on an authentication failure: the ids it didn't get to.
    @remaining_ids = nil
    # What this instance fetched and stored: unchanged / changed / skipped / errors.
    @summary = Granblue::SourceFetchSummary.new('fetch_game_data')
    setup_logger
  end

  def fetch
    timestamp = Time.now.to_i * 1000
    response = self.class.post(
      "/#{page}?_=#{timestamp}&t=#{timestamp}&uid=#{user_id}",
      headers: HEADERS.merge(
        'Cookie' => format_cookies,
        'X-VERSION' => game_version
      )
    )

    raise AuthenticationError if auth_failed?(response)

    response
  end

  # Fetches one style of a character and stores it on that style's row. A style shift
  # shares its base's granblue_id but has its own abilities, so after style 1 this also
  # fetches every other open style in the response's style_list.
  #
  # lang only picks the column (game_raw_en / game_raw_jp): the game's language is an
  # account setting, so the session must already be in that language.
  def fetch_character(granblue_id, style: 1, lang: 'en', other_styles: true)
    timestamp = Time.now.to_i * 1000
    url = "/archive/npc_detail?_=#{timestamp}&t=#{timestamp}&uid=#{user_id}"
    body = {
      special_token: nil,
      user_id: user_id,
      kind_name: '0',
      attribute: '0',
      event_id: nil,
      story_id: nil,
      style: style,
      character_id: granblue_id
    }

    response = fetch_detail(url, body)
    return response unless response

    update_game_data('Character', granblue_id, response, style: style, lang: lang)
    if other_styles && style == 1
      other_open_styles(response).each do |other|
        pause
        fetch_character(granblue_id, style: other, lang: lang, other_styles: false)
      end
    end
    response
  end

  # Stops at the first authentication failure (expired cookies fail every later request
  # too) and leaves the ids it didn't finish in remaining_ids; other errors are counted
  # per character and the run carries on.
  def fetch_characters(granblue_ids, style: nil, lang: 'en')
    granblue_ids.each_with_index do |granblue_id, index|
      pause if index.positive?
      if style
        fetch_character(granblue_id, style: style, lang: lang, other_styles: false)
      else
        fetch_character(granblue_id, lang: lang)
      end
    rescue AuthenticationError => e
      stop_run!('Character', granblue_ids, index, e)
      break
    rescue StandardError => e
      summary.error!(granblue_id, e.message)
      logger.error "Error processing Character #{granblue_id}: #{e.message}"
    end
  end

  def fetch_weapon(granblue_id)
    timestamp = Time.now.to_i * 1000
    url = "/archive/weapon_detail?_=#{timestamp}&t=#{timestamp}&uid=#{user_id}"
    body = {
      special_token: nil,
      user_id: user_id,
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
    url = "/archive/summon_detail?_=#{timestamp}&t=#{timestamp}&uid=#{user_id}"
    body = {
      special_token: nil,
      user_id: user_id,
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

  # Public batch processing methods
  def fetch_all_characters(only_missing: false, lang: 'en')
    process_all_records('Character', only_missing: only_missing, lang: lang)
  end

  def fetch_all_weapons(only_missing: false)
    process_all_records('Weapon', only_missing: only_missing)
  end

  def fetch_all_summons(only_missing: false)
    process_all_records('Summon', only_missing: only_missing)
  end

  private

  def format_cookies
    cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
  end

  # Follow the server's rotating `midship` token by reading it back out of the
  # response Set-Cookie header and storing it for the next request.
  def rotate_midship!(response)
    set_cookie = response.headers['set-cookie']
    return if set_cookie.blank?

    midship = Array(set_cookie).join('; ')[/midship=([^;,\s]+)/, 1]
    @cookies[:midship] = midship if midship.present?
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

  def setup_logger
    @logger = ::Logger.new($stdout)
    @logger.level = debug ? ::Logger::DEBUG : ::Logger::INFO
    @logger.formatter = proc do |severity, _datetime, _progname, msg|
      case severity
      when 'DEBUG'
        debug ? "#{msg}\n" : ''
      else
        "#{msg}\n"
      end
    end

    # Suppress SQL logs in non-debug mode
    return if debug

    ActiveRecord::Base.logger&.level = ::Logger::INFO if defined?(ActiveRecord::Base)
  end

  def fetch_detail(url, body)
    logger.debug "\n=== Request Details ==="
    logger.debug "URL: #{url}"
    logger.debug 'Headers:'
    logger.debug HEADERS.merge(
      'Cookie' => format_cookies,
      'X-VERSION' => game_version
    ).inspect
    logger.debug 'Body:'
    logger.debug body.to_json
    logger.debug '===================='

    response = self.class.post(
      url,
      headers: HEADERS.merge(
        'Cookie' => format_cookies,
        'X-VERSION' => game_version
      ),
      body: body.to_json
    )

    # The server rotates the `midship` token on every response; follow it so a
    # batch keeps a live session instead of dying after the first request.
    rotate_midship!(response)

    logger.debug "\n=== Response Details ==="
    logger.debug "Response code: #{response.code}"
    logger.debug 'Response headers:'
    logger.debug response.headers.inspect
    logger.debug 'Raw response body:'
    logger.debug response.body.inspect
    begin
      logger.debug 'Parsed response body (if JSON):'
      logger.debug JSON.parse(response.body).inspect
    rescue JSON::ParserError => e
      logger.debug "Could not parse as JSON: #{e.message}"
    end
    logger.debug '======================'

    raise AuthenticationError if auth_failed?(response)

    JSON.parse(response.body)
  end

  # Characters: style 2 is the style_swap row, anything else the base row. The response's
  # own style wins over the requested one when they disagree, so a payload never lands on
  # the other style's row.
  def update_game_data(model_name, granblue_id, response_data, style: 1, lang: 'en')
    return unless response_data.is_a?(Hash)

    column = LANG_COLUMNS.fetch(lang.to_s) { raise ArgumentError, "unknown lang #{lang.inspect}" }
    model = Object.const_get(model_name)
    record = if model_name == 'Character'
               # Error and popup responses are hashes too; only a character payload is stored.
               unless response_data['id'].present? && response_data['ability'].present?
                 summary.skipped!('no character payload')
                 logger.warn "Character #{granblue_id}: response has no id or ability; not stored"
                 return
               end
               response_style = response_data['style'].presence&.to_i
               if response_style && response_style != style.to_i
                 summary.skipped!('style mismatch')
                 logger.warn "Character #{granblue_id}: asked for style #{style}, got #{response_style}; not stored"
                 return
               end
               unless [1, 2].include?(style.to_i)
                 summary.skipped!('no row for style')
                 logger.warn "Character #{granblue_id}: no row for style #{style}; not stored"
                 return
               end
               model.find_by(granblue_id: granblue_id, style_swap: style.to_i == 2)
             else
               model.find_by(granblue_id: granblue_id)
             end

    if record
      before = record[column]
      unless record.update(column => response_data)
        summary.error!(granblue_id, record.errors.full_messages.to_sentence)
        return
      end
      summary.fetched!(granblue_id, before: before, after: record[column])
      logger.debug "Updated #{model_name} #{granblue_id} #{column}#{" (style #{style})" if model_name == 'Character'}"
    else
      summary.skipped!('not in database')
      logger.warn "#{model_name} with granblue_id #{granblue_id}#{" (style #{style})" if model_name == 'Character'} not found in database"
    end
  rescue StandardError => e
    summary.error!(granblue_id, e.message)
    logger.error "Error updating #{model_name} #{granblue_id}: #{e.message}"
  end

  # Open styles other than 1 that have a row to store them on.
  def other_open_styles(response)
    Array(response['style_list']).filter_map do |entry|
      next unless entry.is_a?(Hash) && entry['is_open']

      # Only style 2 has a row (style_swap: true) to land on.
      entry['style'].to_i if entry['style'].to_i == 2
    end.uniq
  end

  def process_all_records(model_name, only_missing: false, lang: 'en')
    model = Object.const_get(model_name)
    scope = model
    # Style rows are filled from their base row's style_list, never fetched as style 1.
    scope = scope.where(style_swap: false) if model_name == 'Character'
    scope = scope.where(LANG_COLUMNS.fetch(lang.to_s) => nil) if only_missing

    granblue_ids = scope.order(:granblue_id).pluck(:granblue_id)
    total = granblue_ids.size
    success_count = 0
    error_count = 0

    logger.info "Starting to fetch #{total} #{model_name.downcase}s#{' (missing data only)' if only_missing}..."

    granblue_ids.each_with_index do |granblue_id, index|
      pause if index.positive?
      logger.info "\nProcessing #{model_name} #{granblue_id} (#{index + 1}/#{total})"

      case model_name
      when 'Character' then fetch_character(granblue_id, lang: lang)
      when 'Weapon' then fetch_weapon(granblue_id)
      when 'Summon' then fetch_summon(granblue_id)
      end

      success_count += 1
      logger.debug "Successfully processed #{model_name} #{granblue_id}"
    rescue AuthenticationError => e
      stop_run!(model_name, granblue_ids, index, e)
      break
    rescue StandardError => e
      error_count += 1
      summary.error!(granblue_id, e.message)
      logger.error "Error processing #{model_name} #{granblue_id}: #{e.message}"
    end

    logger.info "\nProcessing complete!"
    logger.info "Total: #{total}"
    logger.info "Successful: #{success_count}"
    logger.info "Failed: #{error_count}"
  end

  def pause
    sleep(delay)
  end

  def stop_run!(model_name, granblue_ids, index, error)
    @remaining_ids = granblue_ids[index..]
    summary.error!(granblue_ids[index], "authentication failed: #{error.message.presence || 'session expired'}")
    logger.error "Authentication failed at #{model_name} #{granblue_ids[index]} after #{index} of #{granblue_ids.size}; " \
                 "stopping (#{@remaining_ids.size} left)."
  end

  class AuthenticationError < StandardError; end
end
