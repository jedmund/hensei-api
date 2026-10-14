# frozen_string_literal: true

module Solomonis
  ##
  # Reads an Evoking Solomonis party deck (the response body of
  # GET /rest/arcarum3/party/deck/<combination_group_id><deck number>).
  #
  # It is the normal deck shape (`deck.pc.weapons/summons/sub_summons`,
  # `deck.npc`, `job`, `set_action`, `quick_user_summon_id`), so the normal
  # deck processors read #body. On top of that it carries the blessing loadout
  # (`deck.blessing`) and `is_position_locked` on every weapon and summon slot.
  #
  # #body is a copy without `deck.pc.param` (it holds the player's user ID,
  # which is never stored) and without `deck.pc.damage_info` (the support
  # summon; Solomonis parties have none).
  #
  # Problems that don't stop an import become warnings (strings).
  class PartyDeck
    # The deck's blessing_id 1..n is arcana number 11..: Justice is 1.
    BLESSING_ARCANA_OFFSET = 10
    NAME_MAX_LENGTH = ReportParser::NAME_MAX_LENGTH

    attr_reader :body, :warnings

    # @param body [Object] the request's party deck
    # @return [Boolean] whether it has the deck shape the processors need
    def self.deck?(body)
      body.is_a?(Hash) && body['deck'].is_a?(Hash) && body['deck']['pc'].is_a?(Hash) &&
        body['deck']['npc'].is_a?(Hash)
    end

    # Turns a deck processor's warning (a hash) into the string the Solomonis
    # imports return.
    def self.warning_text(warning)
      return warning.to_s unless warning.is_a?(Hash)

      details = Array(warning[:details]).to_sentence
      "#{warning[:name] || warning[:granblue_id]} (#{warning[:type]} #{warning[:position]}): " \
        "#{warning[:code].to_s.tr('_', ' ')}#{" — #{details}" if details.present?}"
    end

    # @param body [Hash] a party deck (see .deck?)
    def initialize(body)
      raise ArgumentError, 'not a party deck' unless self.class.deck?(body)

      @body = body.deep_dup
      @body['deck']['pc'].delete('param')
      @body['deck']['pc'].delete('damage_info')
      @warnings = []
    end

    def deck
      body['deck']
    end

    # The route Evoker: the fixed first character slot.
    #
    # @return [String, nil] its granblue_id
    def route_evoker_granblue_id
      slot = deck['npc']['1']
      master = slot['master'] if slot.is_a?(Hash)
      id = master['id'] if master.is_a?(Hash)
      id.to_s.presence if id.is_a?(String) || id.is_a?(Integer)
    end

    # @return [String, nil] the in-game deck name, for the party name
    def name
      value = deck['name']
      return nil unless value.is_a?(String)

      value.squish.truncate(NAME_MAX_LENGTH, omission: '').presence
    end

    ##
    # The equipped blessings (`is_used`), matched to the catalogue by name, or
    # by order when the name doesn't match. Blessings or levels Hensei doesn't
    # have are skipped with a warning.
    #
    # @return [Array<ArcarumBlessingLevel>]
    def blessing_levels
      entries = deck['blessing']
      entries = entries.values if entries.is_a?(Hash)
      return [] unless entries.is_a?(Array)

      catalogue = ArcarumBlessing.includes(:levels).to_a
      entries.select { |entry| entry.is_a?(Hash) && truthy?(entry['is_used']) }.filter_map do |entry|
        blessing_level(entry, catalogue)
      end
    end

    ##
    # Seal state by grid position from `is_position_locked`: locked slots are
    # `sealed`, the others `unsealed`. Starting slots end up `start` whatever
    # this says (the model decides).
    #
    # @return [Hash] `{ weapons: { position => state }, summons: { position => state } }`
    def locked_seal_states
      slot_states { |slot| truthy?(slot['is_position_locked']) ? 'sealed' : 'unsealed' }
    end

    # Every slot `unsealed`: how a finished expedition leaves the grid.
    #
    # @return [Hash] like #locked_seal_states
    def unsealed_seal_states
      slot_states { 'unsealed' }
    end

    private

    def blessing_level(entry, catalogue)
      name = entry['name'].to_s.strip
      blessing = catalogue.find { |b| name.present? && [b.name_en, b.name_jp].include?(name) }
      blessing ||= catalogue.find do |b|
        entry['blessing_id'].to_s.match?(/\A\d{1,3}\z/) &&
          b.arcana_number == entry['blessing_id'].to_i + BLESSING_ARCANA_OFFSET
      end
      label = name.presence || "Blessing #{entry['blessing_id'].to_s.truncate(10)}"
      unless blessing&.released?
        @warnings << "#{label.truncate(40)} isn't a blessing Hensei knows; skipped"
        return nil
      end

      number = entry['level']
      number = number.to_i if number.is_a?(String) && number.match?(/\A\d{1,3}\z/)
      level = blessing.levels.find { |l| l.level == number }
      return level if level

      @warnings << "#{blessing.name_en || blessing.name_jp} has no level #{entry['level'].to_s.truncate(10)}; skipped"
      nil
    end

    # Weapons: slot 1 is the mainhand (-1), slot n is position n - 2.
    # Summons: slot 1 is the main summon (-1), slot n is position n - 2.
    # Sub summons: slot n is position n + 3.
    def slot_states
      pc = deck['pc']
      weapons = slots(pc['weapons']).to_h { |key, slot| [key == 1 ? -1 : key - 2, yield(slot)] }
      summons = slots(pc['summons']).to_h { |key, slot| [key == 1 ? -1 : key - 2, yield(slot)] }
      slots(pc['sub_summons']).each { |key, slot| summons[key + 3] = yield(slot) }
      { weapons: weapons, summons: summons }
    end

    # Filled slots as [slot number, slot].
    def slots(collection)
      return [] unless collection.is_a?(Hash)

      collection.filter_map do |key, slot|
        next unless key.to_s.match?(/\A\d{1,2}\z/) && slot.is_a?(Hash) && slot['master'].is_a?(Hash)

        [key.to_i, slot]
      end
    end

    def truthy?(value)
      [true, 1, '1', 'true'].include?(value)
    end
  end
end
