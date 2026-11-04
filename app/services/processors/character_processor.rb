# frozen_string_literal: true

module Processors
  ##
  # CharacterProcessor builds GridCharacter records from a deck's characters.
  #
  # @example
  #   processor = Processors::CharacterProcessor.new(party, deck_data)
  #   processor.process
  class CharacterProcessor < GridItemProcessor
    grid_item :character, deck_path: %w[deck npc], association: :characters

    CHARACTER_AWAKENING_MAPPING = {
      1 => 'character-balanced',
      2 => 'character-atk',
      3 => 'character-def',
      4 => 'character-multi'
    }.freeze

    private

    def build_items
      @data.dig('deck', 'npc').filter_map { |key, raw_character| build_character(key.to_i, raw_character) }
    end

    # Characters don't report skipped items to the client; they're only logged.
    def skip_item(_item, error)
      log_error "Failed to create GridCharacter: #{error.record.errors.full_messages.join(', ')}"
    end

    def build_character(slot, raw_character)
      return if incomplete?(raw_character)

      param = raw_character['param']
      character_id = raw_character.dig('master', 'id')
      character = find_imported_character(character_id, param['style'])
      unless character
        log_error "Character not found with id #{character_id}"
        return
      end

      grid_character = GridCharacter.new(
        party_id: @party.id,
        character_id: character.id,
        uncap_level: [param['evolution'].to_i, character.max_uncap_level].min,
        transcendence_step: [param['phase'].to_i, character.max_transcendence_stage].min,
        position: slot - 1,
        perpetuity: param['has_npcaugment_constant'],
        awakening: awakening_for(param['npc_arousal_form'].to_i)
      )
      link_collection_character(grid_character, character)
      grid_character
    end

    def awakening_for(arousal_form)
      slug = CHARACTER_AWAKENING_MAPPING[arousal_form] || 'character-balanced'
      Awakening.find_by(slug: slug, object_type: 'Character')
    end

    # The Character for a game id, preferring the style the game reports (style 2 is
    # the Style Shift), then any row with that id.
    def find_imported_character(character_id, style)
      styled = Character.find_by(granblue_id: character_id, style_swap: style == '2')
      styled || Character.find_by(granblue_id: character_id)
    end

    # Links the grid character to the user's collection character, creating one when
    # the user imports to their collection.
    def link_collection_character(grid_character, character)
      link_collection(grid_character, { character_id: character.id },
                      uncap_level: grid_character.uncap_level,
                      transcendence_step: grid_character.transcendence_step,
                      perpetuity: grid_character.perpetuity)
    end

    # The awakening and perpetuity ring, so sync_from_collection! round-trips them.
    def game_customizations(grid_character)
      updates = {}
      if grid_character.awakening_id.present?
        updates[:awakening_id] = grid_character.awakening_id
        updates[:awakening_level] = grid_character.awakening_level || 1
      end
      updates[:perpetuity] = grid_character.perpetuity
      updates
    end
  end
end
