# frozen_string_literal: true

##
# Stores a game detail payload on its catalog row (POST /import/weapons,
# /import/summons, /import/characters): the payload goes in game_raw_<lang>,
# dated now, and the game's series id sets the row's series.
#
# A payload the row can't take raises Rejected with the message and status to
# answer with; a failure while writing raises StoreFailed, caused by the
# original error.
#
# @example
#   GameDataImport.new(:weapon, body, lang: 'en').call
class GameDataImport
  # A payload refused before anything is written.
  class Rejected < StandardError
    attr_reader :status

    def initialize(message, status)
      super(message)
      @status = status
    end
  end

  # A write that failed; the cause is the original error.
  class StoreFailed < StandardError; end

  # What differs between the three kinds as data.
  Kind = Data.define(:catalog, :series_model, :series_slugs)

  LANGUAGES = %w[en jp].freeze

  # GBF series_id to CharacterSeries slug mapping
  CHARACTER_SERIES_SLUGS = {
    1 => 'summer', 2 => 'yukata', 3 => 'valentine', 4 => 'halloween', 5 => 'holiday', 6 => 'zodiac', 7 => 'grand',
    8 => 'fantasy', 9 => 'collab', 10 => 'eternal', 11 => 'evoker', 12 => 'saint', 13 => 'formal'
  }.freeze

  # GBF series_id to WeaponSeries slug mapping
  WEAPON_SERIES_SLUGS = {
    1 => 'seraphic', 2 => 'grand', 3 => 'dark-opus', 4 => 'revenant', 5 => 'primal', 6 => 'beast', 7 => 'regalia',
    8 => 'omega', 9 => 'olden-primal', 10 => 'hollowsky', 11 => 'xeno', 12 => 'rose', 13 => 'ultima', 14 => 'bahamut',
    15 => 'epic', 16 => 'cosmos', 17 => 'superlative', 18 => 'vintage', 19 => 'class-champion', 20 => 'replica',
    21 => 'relic', 22 => 'rusted', 23 => 'sephira', 24 => 'vyrmament', 25 => 'upgrader', 26 => 'astral',
    27 => 'draconic', 28 => 'eternal-splendor', 29 => 'ancestral', 30 => 'new-world-foundation', 31 => 'ennead',
    32 => 'militis', 33 => 'malice', 34 => 'menace', 35 => 'illustrious', 36 => 'proven', 37 => 'revans',
    38 => 'world', 39 => 'exo', 40 => 'draconic-providence', 41 => 'celestial', 42 => 'omega-rebirth',
    43 => 'collab', 44 => 'destroyer'
  }.freeze

  # GBF series_id to SummonSeries slug mapping
  SUMMON_SERIES_SLUGS = {
    1 => 'providence', 2 => 'genesis', 3 => 'magna', 4 => 'optimus', 5 => 'demi-optimus', 6 => 'archangel',
    7 => 'arcarum', 8 => 'epic', 9 => 'carbuncle', 10 => 'dynamis', 12 => 'cryptid', 13 => 'six-dragons',
    14 => 'summer', 15 => 'yukata', 16 => 'holiday', 17 => 'collab', 18 => 'bellum', 19 => 'crest', 20 => 'robur'
  }.freeze

  KINDS = {
    character: Kind.new(catalog: Character, series_model: CharacterSeries, series_slugs: CHARACTER_SERIES_SLUGS),
    weapon: Kind.new(catalog: Weapon, series_model: WeaponSeries, series_slugs: WEAPON_SERIES_SLUGS),
    summon: Kind.new(catalog: Summon, series_model: SummonSeries, series_slugs: SUMMON_SERIES_SLUGS)
  }.freeze

  # @param kind [Symbol] :character, :weapon or :summon
  # @param body [Hash] the game's detail payload
  # @param lang [String, nil] the lang param: the site's language, 'en' or 'jp'
  def initialize(kind, body, lang:)
    @kind = kind
    @config = KINDS.fetch(kind)
    @body = body
    @lang = lang
  end

  ##
  # Finds the row, decides the language and stores the payload.
  #
  # @raise [Rejected] when there is no row for the payload or no language
  # @raise [StoreFailed] when writing fails
  # @return [void]
  def call
    record = @kind == :character ? find_character : find_item
    store(record, @kind == :character ? character_language : item_language)
  end

  private

  def label
    @kind.to_s.capitalize
  end

  def find_item
    record = @config.catalog.find_by(granblue_id: @body['id'])
    return record if record

    Rails.logger.error "[IMPORT] #{label} not found with ID: #{@body['id']}"
    raise Rejected.new("#{label} not found", :not_found)
  end

  # A style shift shares its granblue_id with the base character, so the
  # payload's style picks the row. A style 2 payload never lands on the base
  # row; anything else falls back to any row with the id.
  def find_character
    granblue_id = Granblue::GamePayload.granblue_id(@body)
    style_row = Granblue::GamePayload.style(@body) == '2'
    character = character_row(granblue_id, style_row)
    return character if character

    if style_row && Character.exists?(granblue_id: granblue_id)
      Rails.logger.error "[IMPORT] Style row missing for character #{granblue_id}"
      raise Rejected.new("style row missing for #{granblue_id}", :unprocessable_content)
    end

    Rails.logger.error "[IMPORT] Character not found with ID: #{granblue_id}"
    raise Rejected.new('Character not found', :not_found)
  end

  def character_row(granblue_id, style_row)
    return if granblue_id.blank?
    return Character.find_by(granblue_id: granblue_id, style_swap: true) if style_row

    Character.find_by(granblue_id: granblue_id, style_swap: false) || Character.find_by(granblue_id: granblue_id)
  end

  def item_language
    return @lang if LANGUAGES.include?(@lang)

    Rails.logger.error "[IMPORT] Invalid language: #{@lang}"
    raise Rejected.new('Invalid language', :unprocessable_content)
  end

  # Judged from the payload's skill names: the game answers in the account's
  # language, while the extension's lang follows the site's, so the payload
  # wins and a mismatch is only logged. lang decides a payload that can't be
  # judged.
  def character_language
    detected = Granblue::GamePayload.language(@body)
    requested = @lang.presence_in(LANGUAGES)
    if detected && requested && detected != requested
      Rails.logger.info "[IMPORT] #{Granblue::GamePayload.granblue_id(@body)}: lang=#{requested}, payload reads as " \
                        "#{detected}; stored as #{detected}"
    end
    return detected || requested if detected || requested

    Rails.logger.error '[IMPORT] Invalid language'
    raise Rejected.new('Invalid language', :unprocessable_content)
  end

  def store(record, lang)
    record.update!("game_raw_#{lang}" => @body, "game_raw_#{lang}_fetched_at" => Time.current)
    assign_series(record)
  rescue StandardError => e
    Rails.logger.error "[IMPORT] Failed to update #{@kind} gamedata (#{e.class})"
    raise StoreFailed, e.class.name
  end

  # Characters can be in several series (a membership each); weapons and
  # summons have one.
  def assign_series(record)
    series = payload_series
    return unless series

    if @kind == :character
      return if record.character_series_records.include?(series)

      record.character_series_memberships.create!(character_series: series)
    else
      association = :"#{@kind}_series"
      return if record.public_send(association) == series

      record.update!(association => series)
    end
    Rails.logger.info "[IMPORT] Set series '#{series.slug}' for #{@kind} #{record.granblue_id}"
  end

  def payload_series
    series_id = Granblue::GamePayload.series_id(@body)
    slug = series_id && @config.series_slugs[series_id.to_i]
    slug && @config.series_model.find_by(slug: slug)
  end
end
