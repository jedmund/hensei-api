# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Fetch raw game data (game_raw_en) from the GBF game archive via Dataminer.

    Requires a LIVE game session — extract these from a logged-in
    game.granbluefantasy.jp browser session (cookies) and pass as env vars:
      ACCESS_TOKEN  -> the access_gbtk cookie
      WING          -> the wing cookie
      MIDSHIP       -> the midship cookie (rotates each request — paste a FRESH
                       one and run immediately; the task then follows rotation)
      T             -> the t cookie (optional, defaults to 'dummy')
      GAME_UID      -> the logged-in account's player id (window userId)
      GAME_VERSION  -> the current game build (window version)

    Usage (GAME_UID is named to avoid the shell's reserved UID variable):
      ACCESS_TOKEN=... WING=... MIDSHIP=... GAME_UID=... GAME_VERSION=... rake granblue:fetch_game_data
      ... rake granblue:fetch_game_data type=Weapon          # Weapon | Summon | Character (default)
      ... rake granblue:fetch_game_data force=true           # re-fetch all, not just rows missing game_raw_en
      ... rake granblue:fetch_game_data debug=true           # verbose logging
      ... rake granblue:fetch_game_data ids=3040377000,3040088000   # these characters only (always fetched)
      ... rake granblue:fetch_game_data ids=3040377000 style=2      # one style only (2 = the style_swap row)
      ... rake granblue:fetch_game_data lang=jp              # store in game_raw_jp
      ... rake granblue:fetch_game_data delay=3              # seconds between requests (default and minimum 2)
      ... rake granblue:fetch_game_data changed_out=tmp/game_changed.txt   # write the changed granblue_ids
      ... rake granblue:fetch_game_data build=shadow         # Characters: build the changed ones afterwards (or build=write)

    Characters: style 1 lands on the base row, and every other open style in its
    style_list is fetched onto that style's row (style_swap: true).
    lang only picks the column: the game's language is an account setting, so set the
    account to Japanese before fetching with lang=jp.

    Fetches only records missing the column by default; at least 2s between requests.
    Prints a summary: fetched (unchanged = same payload as stored, changed), skipped, errors.
    Character writes don't queue a build per row; without build= the task prints the
    build command to run next.
  DESC
  task fetch_game_data: :environment do
    required = { 'ACCESS_TOKEN' => ENV.fetch('ACCESS_TOKEN', nil), 'WING' => ENV.fetch('WING', nil), 'MIDSHIP' => ENV.fetch('MIDSHIP', nil) }
    missing = required.select { |_k, v| v.blank? }.keys
    if missing.any?
      warn "Missing required env vars: #{missing.join(', ')}"
      warn 'Extract them from a logged-in game.granbluefantasy.jp session (cookies: access_gbtk, wing, midship).'
      exit 1
    end

    type = (ENV['type'] || 'Character').classify
    unless %w[Character Weapon Summon].include?(type)
      warn "Invalid type '#{type}'. Must be one of: Character, Weapon, Summon."
      exit 1
    end

    lang = ENV['lang'].presence || 'en'
    unless Dataminer::LANG_COLUMNS.key?(lang)
      warn "Invalid lang '#{lang}'. Must be one of: #{Dataminer::LANG_COLUMNS.keys.join(', ')}."
      exit 1
    end
    ids = ENV['ids'].to_s.split(',').map(&:strip).compact_blank
    style = ENV['style'].presence&.to_i
    if (ids.any? || style || lang != 'en') && type != 'Character'
      warn 'ids=, style= and lang= only apply to type=Character.'
      exit 1
    end

    begin
      build = CharacterSkills::SourceFetch.build_mode(ENV.fetch('build', nil))
    rescue CharacterSkills::SourceFetch::OptionError => e
      abort "Error: #{e.message}"
    end
    abort 'Error: build= only applies to type=Character.' if build && type != 'Character'

    only_missing = ENV['force'] != 'true'
    miner = Dataminer.new(
      page: 'archive',
      access_token: required['ACCESS_TOKEN'],
      wing: required['WING'],
      midship: required['MIDSHIP'],
      t: ENV['T'].presence || 'dummy',
      user_id: ENV['GAME_UID'].presence || Dataminer::BOT_UID,
      game_version: ENV['GAME_VERSION'].presence || Dataminer::GAME_VERSION,
      debug: ENV['debug'] == 'true',
      delay: Dataminer.clamp_delay(ENV['delay'].presence, warn: method(:puts))
    )

    if style && ids.empty?
      warn 'style= needs ids=.'
      exit 1
    end

    Character.without_skill_build do
      if ids.any?
        puts "Fetching game data (#{lang}) for #{ids.size} characters#{" (style #{style})" if style}..."
        miner.fetch_characters(ids, style: style, lang: lang)
      elsif type == 'Character'
        puts "Fetching game data (#{lang}) for Characters#{' (missing only)' if only_missing}..."
        miner.fetch_all_characters(only_missing: only_missing, lang: lang)
      else
        puts "Fetching game data for #{type.pluralize}#{' (missing only)' if only_missing}..."
        miner.public_send(:"fetch_all_#{type.downcase.pluralize}", only_missing: only_missing)
      end
    end

    miner.summary.print($stdout)
    if type == 'Character'
      CharacterSkills::SourceFetch.finish(miner.summary, build: build, changed_out: ENV['changed_out'].presence)
    elsif ENV['changed_out'].present?
      miner.summary.write_changed(ENV['changed_out'])
    end
  end
end
