# frozen_string_literal: true

module Processors
  ##
  # CharacterProcessor processes an array of character data and creates GridCharacter records.
  #
  # @example
  #   processor = Processors::CharacterProcessor.new(party, transformed_characters_array)
  #   processor.process
  class CharacterProcessor < BaseProcessor
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
      characters_data = @data['deck']['npc']

      grid_characters = process_characters(characters_data)
      grid_characters.each do |grid_character|
        begin
          grid_character.save!
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[CHARACTER] Failed to create GridCharacter: #{e.record.errors.full_messages.join(', ')}"
        end
      end

    rescue StandardError => e
      raise e
    end

    private

    def process_characters(characters_data)
      characters_data.map do |key, raw_character|
        next if raw_character.nil? || raw_character['param'].nil? || raw_character['master'].nil?

        position = key.to_i - 1

        # Find the Character record by its granblue_id.
        character_id = raw_character.dig('master', 'id')
        character = Character.find_by(granblue_id: character_id)

        unless character
          Rails.logger.error "[CHARACTER] Character not found with id #{character_id}"
          next
        end

        # The deck doesn't have Awakening data, so use the default
        awakening = Awakening.where(slug: 'character-balanced').first
        grid_character = GridCharacter.create(
          party_id: @party.id,
          character_id: character.id,
          uncap_level: raw_character.dig('param', 'evolution').to_i,
          transcendence_step: raw_character.dig('param', 'phase').to_i,
          position: position,
          perpetuity: raw_character.dig('param', 'has_npcaugment_constant'),
          awakening: awakening
        )

        grid_character
      end.compact
    end

    # Converts a value to a boolean.
    def parse_boolean(val)
      val.to_s.downcase == 'true'
    end
  end
end
