# frozen_string_literal: true

##
# Service for importing characters from game JSON data.
# Parses the game's character inventory data and creates CollectionCharacter records.
#
# Supports two data formats:
# 1. Game inventory format: { param: { id: ... }, master: { id: granblue_id } }
# 2. Extension stats format: { granblue_id: '...', awakening_type: 1, ring1: {...}, ... }
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

  # Map GBF npc_arousal_form to hensei awakening slugs
  # GBF character awakenings: 1=Balanced, 2=Attack, 3=Defense, 4=Multiattack
  GBF_AWAKENING_MAP = {
    1 => 'character-balanced', # Balanced
    2 => 'character-atk',      # Attack
    3 => 'character-def',      # Defense
    4 => 'character-multi'     # Multiattack
    # All others default to character-balanced
  }.freeze

  def initialize(user, game_data, options = {})
    @user = user
    @game_data = game_data
    @update_existing = options[:update_existing] || false
    @created = []
    @updated = []
    @skipped = []
    @errors = []
    @default_awakening = nil
    @awakening_cache = {}
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
    # Detect format: extension stats format has granblue_id at top level
    if item['granblue_id'].present?
      import_stats_format(item)
    else
      import_game_format(item)
    end
  end

  # Import from game inventory format: { param: {...}, master: { id: granblue_id } }
  def import_game_format(item)
    param = item['param'] || {}
    master = item['master'] || {}

    granblue_id = master['id']
    game_id = param['id']

    character = find_character(granblue_id)
    unless character
      @errors << { game_id: game_id, granblue_id: granblue_id, error: 'Character not found' }
      return
    end

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

  # Import from extension stats format: { granblue_id: '...', awakening_type: 1, ring1: {...}, ... }
  def import_stats_format(item)
    granblue_id = item['granblue_id']

    character = find_character(granblue_id)
    unless character
      @errors << { granblue_id: granblue_id, error: 'Character not found' }
      return
    end

    existing = @user.collection_characters.find_by(character_id: character.id)

    if existing
      if @update_existing
        update_existing_stats(existing, item, character)
      else
        @skipped << { granblue_id: granblue_id, character_id: character.id, reason: 'Already exists' }
      end
      return
    end

    create_collection_character_from_stats(item, character)
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

    uncap = parse_uncap_level(param['evolution'])
    transcendence = parse_transcendence_step(param['phase'])

    # Transcended characters have uncap_level 6 (beyond the normal 0-5 range)
    uncap = 6 if transcendence > 0 && uncap >= 5

    attrs = {
      character: character,
      uncap_level: uncap,
      transcendence_step: transcendence
    }

    # Only set awakening_level if > 1 (requires awakening to be set)
    # The model's before_save callback will set default awakening
    if awakening_level > 1
      attrs[:awakening] = default_awakening
      attrs[:awakening_level] = awakening_level
    end

    # Only set perpetuity when true; the field is unreliable (sometimes
    # false even for ringed characters), so never overwrite a known true.
    attrs[:perpetuity] = true if param['has_npcaugment_constant']

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

  # Stats format methods

  def create_collection_character_from_stats(item, character)
    attrs = build_stats_attrs(item, character)

    collection_character = @user.collection_characters.build(attrs)

    if collection_character.save
      @created << collection_character
    else
      @errors << {
        granblue_id: character.granblue_id,
        error: collection_character.errors.full_messages.join(', ')
      }
    end
  end

  def update_existing_stats(existing, item, character)
    attrs = build_stats_attrs(item, character)

    if existing.update(attrs)
      @updated << existing
    else
      @errors << {
        granblue_id: character.granblue_id,
        error: existing.errors.full_messages.join(', ')
      }
    end
  end

  def build_stats_attrs(item, character)
    attrs = { character: character }

    # Uncap level and transcendence
    if item['uncap_level'].present?
      uncap = parse_uncap_level(item['uncap_level'])
      transcendence = item['transcendence_step'].present? ? parse_transcendence_step(item['transcendence_step']) : 0
      uncap = 6 if transcendence > 0 && uncap >= 5
      attrs[:uncap_level] = uncap
      attrs[:transcendence_step] = transcendence
    end

    # Awakening type and level
    if item['awakening_type'].present?
      attrs[:awakening] = find_awakening_by_type(item['awakening_type'])
      attrs[:awakening_level] = parse_awakening_level(item['awakening_level'])
    end

    # Rings (up to 4)
    attrs[:ring1] = parse_ring(item['ring1']) if item['ring1'].present?
    attrs[:ring2] = parse_ring(item['ring2']) if item['ring2'].present?
    attrs[:ring3] = parse_ring(item['ring3']) if item['ring3'].present?
    attrs[:ring4] = parse_ring(item['ring4']) if item['ring4'].present?

    # Earring
    attrs[:earring] = parse_ring(item['earring']) if item['earring'].present?

    # Perpetuity ring status
    attrs[:perpetuity] = item['perpetuity'] if item.key?('perpetuity')

    attrs
  end

  def find_awakening_by_type(gbf_type)
    slug = GBF_AWAKENING_MAP[gbf_type.to_i] || 'character-balanced'
    @awakening_cache[slug] ||= Awakening.find_by(slug: slug, object_type: 'Character')
  end

  def parse_ring(ring_data)
    return nil unless ring_data.is_a?(Hash)
    return nil unless ring_data['modifier'].present?

    {
      'modifier' => ring_data['modifier'].to_i,
      'strength' => ring_data['strength'].to_i
    }
  end
end
