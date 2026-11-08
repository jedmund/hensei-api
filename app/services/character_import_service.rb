# frozen_string_literal: true

##
# Imports characters into the user's CollectionCharacter records. The shared
# flow is CollectionImport::Base.
#
# Supports two data formats:
# 1. Game inventory format: { param: { id: ... }, master: { id: granblue_id } }
# 2. Extension stats format: { granblue_id: '...', awakening_type: 1, ring1: {...}, ... }
#
# Unlike weapons and summons, characters are unique per user: each character
# is in a user's collection at most once, so an item matches the user's copy
# by character, not by game_id, and there is no deletion sync.
#
# @example Import characters for a user
#   result = CharacterImportService.new(user, game_data).import
#   result.created.size # => characters added
#
class CharacterImportService < CollectionImport::Base
  collection_import :character

  # Map GBF npc_arousal_form to hensei awakening slugs
  # GBF character awakenings: 1=Balanced, 2=Attack, 3=Defense, 4=Multiattack
  GBF_AWAKENING_MAP = {
    1 => 'character-balanced', # Balanced
    2 => 'character-atk',      # Attack
    3 => 'character-def',      # Defense
    4 => 'character-multi'     # Multiattack
    # All others default to character-balanced
  }.freeze

  RING_SLOTS = %w[ring1 ring2 ring3 ring4 earring].freeze

  def initialize(user, game_data, options = {})
    super
    @awakening_cache = {}
  end

  ##
  # Dry run: the diff that import with update_existing would apply to each
  # character the user owns, in either format. Characters the user doesn't
  # own are left out.
  #
  # @return [Array<Hash>] one entry per changed record: { granblue_id:, changes: [...] }
  def preview_updates
    items = extract_items
    prepare(items)
    items.filter_map do |item|
      granblue_id = item_granblue_id(item)
      next if granblue_id.blank?

      character = find_character(granblue_id)
      existing = character && @owned[character.id]
      next unless existing

      existing.assign_attributes(build_attrs(item, character))
      next if existing.changes.empty?

      { granblue_id: character.granblue_id, changes: CollectionImport::ChangeFormatter.format(existing.changes) }
    end
  end

  private

  # The extension stats format has granblue_id at the top level.
  def stats_format?(item)
    item['granblue_id'].present?
  end

  def item_granblue_id(item)
    stats_format?(item) ? item['granblue_id'] : (item['master'] || {})['id']
  end

  def import_item(item)
    character = find_character(item_granblue_id(item))
    return record_not_found(item) unless character

    save_item(item, character, @owned[character.id])
  end

  # The characters the list names and the user's copies of them, in two
  # queries. A style-shifted character shares its granblue_id with the base
  # character; the game's lists don't say which, so the base one is used.
  def prepare(items)
    ids = items.filter_map { |item| item_granblue_id(item).presence&.to_s }.uniq
    @characters = Character.where(granblue_id: ids).order(:style_swap).group_by(&:granblue_id)
                           .transform_values(&:first)
    @owned = collection.where(character_id: @characters.values.map(&:id)).index_by(&:character_id)
  end

  def remember(record)
    @owned[record.character_id] = record
  end

  def find_character(granblue_id)
    @characters[granblue_id.to_s]
  end

  def item_ref(item, character = nil)
    granblue_id = character ? character.granblue_id : item_granblue_id(item)
    return { granblue_id: granblue_id } if stats_format?(item)

    { game_id: (item['param'] || {})['id'], granblue_id: granblue_id }
  end

  def skip_entry(item, character, reason)
    key = stats_format?(item) ? { granblue_id: item['granblue_id'] } : { game_id: (item['param'] || {})['id'] }
    key.merge(character_id: character.id, reason: reason)
  end

  def build_attrs(item, character)
    stats_format?(item) ? build_stats_attrs(item, character) : build_game_attrs(item, character)
  end

  def build_game_attrs(item, character)
    param = item['param'] || {}
    attrs = {
      character: character,
      **game_uncap(param['evolution'], param['phase'], max_transcendence: character.max_transcendence_stage)
    }

    # Only set awakening_level if > 1 (requires awakening to be set)
    awakening_level = parse_awakening_level(param['arousal_level'])
    if awakening_level > 1
      attrs[:awakening] = find_awakening_by_type(1)
      attrs[:awakening_level] = awakening_level
    end

    # Only set perpetuity when true; the field is unreliable (sometimes
    # false even for ringed characters), so never overwrite a known true.
    attrs[:perpetuity] = true if param['has_npcaugment_constant']
    attrs
  end

  def build_stats_attrs(item, character)
    attrs = { character: character }

    if item['uncap_level'].present?
      attrs.merge!(game_uncap(item['uncap_level'], item['transcendence_step'].presence,
                              max_transcendence: character.max_transcendence_stage))
    end

    if item['awakening_type'].present?
      attrs[:awakening] = find_awakening_by_type(item['awakening_type'])
      attrs[:awakening_level] = parse_awakening_level(item['awakening_level'])
    end

    RING_SLOTS.each { |slot| attrs[slot.to_sym] = parse_ring(item[slot]) if item[slot].present? }
    attrs[:perpetuity] = item['perpetuity'] if item.key?('perpetuity')
    attrs
  end

  # Below 1 (or missing) is 1; the game's max is 10.
  def parse_awakening_level(arousal_level)
    [arousal_level.to_i, 1].max.clamp(1, 10)
  end

  def find_awakening_by_type(gbf_type)
    slug = GBF_AWAKENING_MAP[gbf_type.to_i] || 'character-balanced'
    @awakening_cache[slug] ||= Awakening.find_by(slug: slug, object_type: 'Character')
  end

  def parse_ring(ring_data)
    return nil unless ring_data.is_a?(Hash)
    return nil if ring_data['modifier'].blank?

    { 'modifier' => ring_data['modifier'].to_i, 'strength' => ring_data['strength'].to_i }
  end
end
