# frozen_string_literal: true

##
# Service for importing characters from game JSON data.
# Parses the game's character inventory data and creates CollectionCharacter records.
#
# Note: Unlike weapons and summons, characters are unique per user - each character
# can only be in a user's collection once.
#
# @example Import characters for a user
#   service = CharacterImportService.new(user, game_data)
#   result = service.import
#   if result.success?
#     puts "Imported #{result.created.size} characters"
#   end
#
class CharacterImportService
  Result = Struct.new(:success?, :created, :updated, :skipped, :errors, keyword_init: true)

  def initialize(user, game_data, options = {})
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @created = []
    @updated = []
    @skipped = []
    @errors = []
    @default_awakening = nil
  end

  ##
  # Imports characters from game data.
  #
  # @return [Result] Import result with counts and errors
  def import
    items = extract_items
    return Result.new(success?: false, created: [], updated: [], skipped: [], errors: ['No character items found in data']) if items.empty?

    ActiveRecord::Base.transaction do
      items.each_with_index do |item, index|
        import_item(item, index)
      rescue StandardError => e
        @errors << { index: index, game_id: item.dig('param', 'id'), error: e.message }
      end
    end

    Result.new(
      success?: @errors.empty?,
      created: @created,
      updated: @updated,
      skipped: @skipped,
      errors: @errors
    )
  end

  private

  def extract_items
    return @game_data if @game_data.is_a?(Array)
    return @game_data['list'] if @game_data.is_a?(Hash) && @game_data['list'].is_a?(Array)

    []
  end

  def import_item(item, _index)
    param = item['param'] || {}
    master = item['master'] || {}

    # The character's granblue_id is in master.id
    granblue_id = master['id']
    game_id = param['id']

    character = find_character(granblue_id)
    unless character
      @errors << { game_id: game_id, granblue_id: granblue_id, error: 'Character not found' }
      return
    end

    # Characters are unique per user - check by character_id, not game_id
    existing = @user.collection_characters.find_by(character_id: character.id)

    if existing
      if @update_existing
        update_existing_character(existing, item, character)
      else
        @skipped << { game_id: game_id, character_id: character.id, reason: 'Already exists' }
      end
      return
    end

    create_collection_character(item, character)
  end

  def find_character(granblue_id)
    Character.find_by(granblue_id: granblue_id.to_s)
  end

  def create_collection_character(item, character)
    attrs = build_collection_character_attrs(item, character)

    collection_character = @user.collection_characters.build(attrs)

    if collection_character.save
      @created << collection_character
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: character.granblue_id,
        error: collection_character.errors.full_messages.join(', ')
      }
    end
  end

  def update_existing_character(existing, item, character)
    attrs = build_collection_character_attrs(item, character)

    if existing.update(attrs)
      @updated << existing
    else
      @errors << {
        game_id: item.dig('param', 'id'),
        granblue_id: character.granblue_id,
        error: existing.errors.full_messages.join(', ')
      }
    end
  end

  def build_collection_character_attrs(item, character)
    param = item['param'] || {}
    awakening_level = parse_awakening_level(param['arousal_level'])

    attrs = {
      character: character,
      uncap_level: parse_uncap_level(param['evolution']),
      transcendence_step: parse_transcendence_step(param['phase'])
    }

    # Only set awakening_level if > 1 (requires awakening to be set)
    # The model's before_save callback will set default awakening
    if awakening_level > 1
      attrs[:awakening] = default_awakening
      attrs[:awakening_level] = awakening_level
    end

    attrs
  end

  def default_awakening
    @default_awakening ||= Awakening.find_by(slug: 'character-balanced', object_type: 'Character')
  end

  def parse_uncap_level(evolution)
    value = evolution.to_i
    # Evolution 6 = transcended, but uncap_level maxes at 5
    value.clamp(0, 5)
  end

  def parse_transcendence_step(phase)
    value = phase.to_i
    value.clamp(0, 10)
  end

  def parse_awakening_level(arousal_level)
    value = arousal_level.to_i
    # Default to 1 if not present or 0
    value = 1 if value < 1
    value.clamp(1, 10)
  end
end
