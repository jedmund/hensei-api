# frozen_string_literal: true

module Processors
  ##
  # CharacterProcessor processes an array of character data and creates GridCharacter records.
  #
  # @example
  #   processor = Processors::CharacterProcessor.new(party, transformed_characters_array)
  #   processor.process
  class CharacterProcessor < BaseProcessor
    CHARACTER_AWAKENING_MAPPING = {
      1 => 'character-balanced',
      2 => 'character-atk',
      3 => 'character-def',
      4 => 'character-multi'
    }.freeze

    def initialize(party, data, type = :normal, options = {})
      super(party, data, options)
      @party = party
      @data = data
    end

    ##
    # Processes character data.
    #
    # Iterates over each character hash in +data+ and creates a new GridCharacter record.
    # Expects each character hash to include keys such as :id, :position, :uncap, etc.
    #
    # @return [void]
    def process
      unless @data.is_a?(Hash)
        Rails.logger.error "[CHARACTER] Invalid data format: expected a Hash, got #{@data.class}"
        return
      end

      unless @data.key?('deck') && @data['deck'].key?('npc')
        Rails.logger.error '[CHARACTER] Missing npc data in deck JSON'
        return
      end

      @data = @data.with_indifferent_access
      characters_data = @data.dig('deck', 'npc')

      grid_characters = process_characters(characters_data)
      grid_characters.each do |grid_character|
        begin
          grid_character.save!
          if grid_character.collection_character.present?
            update_collection_from_game(grid_character)
            begin
              grid_character.sync_from_collection!
            rescue ActiveRecord::RecordInvalid => e
              Rails.logger.error "[CHARACTER] Sync from collection failed, reverting: #{e.record.errors.full_messages.join(', ')}"
              grid_character.reload
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[CHARACTER] Failed to create GridCharacter: #{e.record.errors.full_messages.join(', ')}"
        end
      end

    rescue StandardError => e
      raise e
    end

    private

    def update_collection_from_game(grid_character)
      cc = grid_character.collection_character
      return unless cc.character_id == grid_character.character_id

      updates = {}
      updates[:uncap_level] = grid_character.uncap_level if grid_character.uncap_level > cc.uncap_level
      updates[:transcendence_step] = grid_character.transcendence_step if grid_character.transcendence_step > cc.transcendence_step

      if updates.any?
        cc.update!(updates)
        Rails.logger.info "[CHARACTER] Updated collection character #{cc.id} from game data: #{updates}"
      end
    end

    def process_characters(characters_data)
      characters_data.map do |key, raw_character|
        next if raw_character.nil? || raw_character['param'].nil? || raw_character['master'].nil?

        position = key.to_i - 1

        # Find the Character record by its granblue_id, respecting style change.
        character_id = raw_character.dig('master', 'id')
        style = raw_character.dig('param', 'style')

        character = if style == '2'
                      Character.find_by(granblue_id: character_id, style_swap: true) ||
                        Character.find_by(granblue_id: character_id)
                    else
                      Character.find_by(granblue_id: character_id, style_swap: false) ||
                        Character.find_by(granblue_id: character_id)
                    end

        unless character
          Rails.logger.error "[CHARACTER] Character not found with id #{character_id}"
          next
        end

        arousal_form = raw_character.dig('param', 'npc_arousal_form').to_i
        awakening_slug = CHARACTER_AWAKENING_MAPPING[arousal_form] || 'character-balanced'
        awakening = Awakening.find_by(slug: awakening_slug, object_type: 'Character')
        grid_character = GridCharacter.new(
          party_id: @party.id,
          character_id: character.id,
          uncap_level: raw_character.dig('param', 'evolution').to_i,
          transcendence_step: raw_character.dig('param', 'phase').to_i,
          position: position,
          perpetuity: raw_character.dig('param', 'has_npcaugment_constant'),
          awakening: awakening
        )

        # Link to collection character if available, or create one
        collection_character = @party.user.collection_characters.find_by(character_id: character.id)

        if collection_character.nil? && @party.user.import_weapons
          begin
            collection_character = @party.user.collection_characters.create!(
              character_id: character.id,
              uncap_level: grid_character.uncap_level,
              transcendence_step: grid_character.transcendence_step,
              perpetuity: grid_character.perpetuity
            )
          rescue StandardError => e
            Rails.logger.error "[CHARACTER] Failed to create collection character during import: #{e.message}"
            collection_character = nil
          end
        end

        grid_character.collection_character = collection_character if collection_character

        grid_character
      end.compact
    end

    # Converts a value to a boolean.
    def parse_boolean(val)
      val.to_s.downcase == 'true'
    end
  end
end
