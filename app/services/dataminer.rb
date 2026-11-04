# frozen_string_literal: true

##
# Fetches raw game data (the archive detail pages) for characters, weapons and
# summons and stores it as each row's game_raw_* source. Requests go through a
# Dataminer::Session; payloads are stored by a Dataminer::PayloadStore, which
# records the run's summary.
class Dataminer
  BOT_UID = '39094985'
  GAME_VERSION = '1741068713'
  # Seconds between two requests to the game, at least (the same pace as the wikis).
  MIN_DELAY = 2.0
  LANG_COLUMNS = { 'en' => :game_raw_en, 'jp' => :game_raw_jp, 'ja' => :game_raw_jp }.freeze

  attr_reader :page, :logger, :debug, :user_id, :game_version, :summary, :delay,
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
  def initialize(page:, access_token:, wing:, midship:, t_cookie: 'dummy',
                 user_id: BOT_UID, game_version: GAME_VERSION, debug: false, delay: MIN_DELAY)
    @page = page
    @cookies = { access_gbtk: access_token, wing: wing, t: t_cookie, midship: midship }
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
    session.post_page(page)
  end

  # Fetches one style of a character and stores it on that style's row. A style shift
  # shares its base's granblue_id but has its own abilities, so after style 1 this also
  # fetches every other open style in the response's style_list.
  #
  # lang only picks the column (game_raw_en / game_raw_jp): the game's language is an
  # account setting, so the session must already be in that language.
  def fetch_character(granblue_id, style: 1, lang: 'en', other_styles: true)
    response = session.detail('npc', style: style, character_id: granblue_id)
    return response unless response

    payload_store.store('Character', granblue_id, response, style: style, lang: lang)
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
    response = session.detail('weapon', weapon_id: granblue_id)
    payload_store.store('Weapon', granblue_id, response) if response
    response
  end

  def fetch_summon(granblue_id)
    response = session.detail('summon', summon_id: granblue_id)
    payload_store.store('Summon', granblue_id, response) if response
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

  def session
    @session ||= Session.new(cookies: @cookies, user_id: user_id, game_version: game_version, logger: logger)
  end

  def payload_store
    @payload_store ||= PayloadStore.new(summary: summary, logger: logger)
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

  # Rows with no payload for column; a character's is a source.
  def missing_scope(scope, column)
    scope.respond_to?(:without_source) ? scope.without_source(column) : scope.where(column => nil)
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
    granblue_ids = ids_to_fetch(model_name, only_missing, lang)
    logger.info "Starting to fetch #{granblue_ids.size} #{model_name.downcase}s#{' (missing data only)' if only_missing}..."

    success_count, error_count = fetch_each(model_name, granblue_ids, lang)

    logger.info "\nProcessing complete!"
    logger.info "Total: #{granblue_ids.size}"
    logger.info "Successful: #{success_count}"
    logger.info "Failed: #{error_count}"
  end

  def ids_to_fetch(model_name, only_missing, lang)
    scope = Object.const_get(model_name).all
    # Style rows are filled from their base row's style_list, never fetched as style 1.
    scope = scope.where(style_swap: false) if model_name == 'Character'
    scope = missing_scope(scope, LANG_COLUMNS.fetch(lang.to_s)) if only_missing
    scope.order(:granblue_id).pluck(:granblue_id)
  end

  # @return [Array(Integer, Integer)] the successful and failed counts
  def fetch_each(model_name, granblue_ids, lang)
    counts = [0, 0]
    granblue_ids.each_with_index do |granblue_id, index|
      pause if index.positive?
      logger.info "\nProcessing #{model_name} #{granblue_id} (#{index + 1}/#{granblue_ids.size})"
      fetch_one(model_name, granblue_id, lang)
      counts[0] += 1
      logger.debug "Successfully processed #{model_name} #{granblue_id}"
    rescue AuthenticationError => e
      stop_run!(model_name, granblue_ids, index, e)
      break
    rescue StandardError => e
      counts[1] += 1
      summary.error!(granblue_id, e.message)
      logger.error "Error processing #{model_name} #{granblue_id}: #{e.message}"
    end
    counts
  end

  def fetch_one(model_name, granblue_id, lang)
    case model_name
    when 'Character' then fetch_character(granblue_id, lang: lang)
    when 'Weapon' then fetch_weapon(granblue_id)
    when 'Summon' then fetch_summon(granblue_id)
    end
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
