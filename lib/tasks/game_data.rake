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

    Fetches only records missing game_raw_en by default; throttled ~1 req/sec.
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

    only_missing = ENV['force'] != 'true'
    miner = Dataminer.new(
      page: 'archive',
      access_token: required['ACCESS_TOKEN'],
      wing: required['WING'],
      midship: required['MIDSHIP'],
      t: ENV['T'].presence || 'dummy',
      user_id: ENV['GAME_UID'].presence || Dataminer::BOT_UID,
      game_version: ENV['GAME_VERSION'].presence || Dataminer::GAME_VERSION,
      debug: ENV['debug'] == 'true'
    )

    puts "Fetching game data for #{type.pluralize}#{' (missing only)' if only_missing}..."
    miner.public_send(:"fetch_all_#{type.downcase.pluralize}", only_missing: only_missing)
  end
end
