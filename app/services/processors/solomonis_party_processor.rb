# frozen_string_literal: true

module Processors
  ##
  # Imports an Evoking Solomonis party from the game's party deck
  # (`kind: "solomonis_party"` on POST /import) into a new party.
  #
  # The route Evoker is the deck's fixed first character. The party name is the
  # deck's name, the pledge level 0 and the blessings the deck has equipped.
  # Class, skills, characters, weapons and summons go through the normal deck
  # processors, so uncaps, awakening, keys, AX, collection links and the quick
  # summon import exactly as for a normal deck. There is no support summon.
  # Weapons and summons the game shows as locked are `sealed`, the others
  # `unsealed` (starting slots stay `start`). The unseal priority is never
  # imported.
  #
  # Warnings are strings, as for the run import.
  class SolomonisPartyProcessor < BaseProcessor
    ImportError = SolomonisProcessor::ImportError

    # Checks the payload's shape before any database work.
    #
    # @param data [Hash] the request's `solomonis` object
    # @raise [ImportError]
    def self.validate!(data)
      return if data.is_a?(Hash) && Solomonis::PartyDeck.deck?(data['deck'])

      raise ImportError.new('invalid_data', 'solomonis.deck must be a party deck')
    end

    # Party: a new, unsaved party with its user and visibility. Data: the
    # request's `solomonis` object.
    def process
      self.class.validate!(data)
      @deck = Solomonis::PartyDeck.new(data['deck'])

      assign_expedition
      save_party
      import_blessings
      import_grid
      party.apply_solomonis_seal_states!(**@deck.locked_seal_states)
      @warnings.concat(@deck.warnings)
      party
    end

    private

    def assign_expedition
      evoker_id = @deck.route_evoker_granblue_id
      evoker = evoker_id && Character.solomonis_route_evokers.find_by(granblue_id: evoker_id)
      raise ImportError.new('unknown_route_evoker', "The deck's Evoker can't lead an expedition") unless evoker

      expedition = party.assign_solomonis_route(evoker)
      expedition.pledge_level = 0
      party.name = @deck.name if party.name.blank?
      party.last_updated = Time.current
    end

    # The in-game deck name is the default name, so a name the profanity
    # filter rejects is dropped rather than failing the import.
    def save_party
      if !party.valid? && party.errors.attribute_names == [:name]
        @warnings << "The party name wasn't accepted; left empty"
        party.name = nil
      end
      party.save!
    end

    def import_blessings
      levels = @deck.blessing_levels
      return if levels.empty?

      party.replace_solomonis_blessings!(levels)
    rescue ActiveRecord::RecordInvalid => e
      @warnings << "Blessings weren't imported (#{e.record.errors.full_messages.to_sentence})"
    end

    def import_grid
      processors = [JobProcessor, CharacterProcessor, SummonProcessor, WeaponProcessor].map do |klass|
        klass.new(party, @deck.body)
      end
      processors.each(&:process)
      processors.flat_map(&:warnings).each { |warning| @warnings << Solomonis::PartyDeck.warning_text(warning) }
    end
  end
end
