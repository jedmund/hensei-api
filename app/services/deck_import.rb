# frozen_string_literal: true

##
# Builds a new party from a game party deck (POST /import without a kind).
# The deck processors add the job, characters, summons, weapons and bullets;
# then the raid is set (the one the user picked, else one detected from the
# deck's size) and the party is added to the requested playlists.
#
# @example
#   error = DeckImport.payload_error(body)
#   party, warnings = DeckImport.new(user, body).call unless error
class DeckImport
  PROCESSORS = [
    Processors::JobProcessor,
    Processors::CharacterProcessor,
    Processors::SummonProcessor,
    Processors::WeaponProcessor,
    Processors::BulletProcessor
  ].freeze

  ##
  # Checks that the body holds a deck under 'import'.
  #
  # @param body [Hash] the parsed request body
  # @return [String, nil] the error to answer with, or nil for a usable deck
  def self.payload_error(body)
    data = body['import']
    unless data.is_a?(Hash)
      Rails.logger.error "[IMPORT] 'import' key is missing or not a hash."
      return 'Invalid JSON data'
    end
    return if data['deck'].is_a?(Hash) && data['deck'].key?('pc') && data['deck'].key?('npc')

    Rails.logger.error '[IMPORT] Deck data incomplete or missing.'
    'Invalid deck data'
  end

  # @param user [User, nil] the importing user
  # @param body [Hash] a body payload_error accepted
  def initialize(user, body)
    @user = user
    @body = body
    @deck = body['import']
    @options = PartyImportOptions.new(user, body)
  end

  ##
  # Creates the party and its grid in one transaction.
  #
  # @return [Array(Party, Array<Hash>)] the party and the processors' warnings
  def call
    Rails.logger.info '[IMPORT] Starting import...'
    party = nil
    warnings = []
    ActiveRecord::Base.transaction do
      party = Party.create!(user: @user, visibility: @options.visibility, name: @body['name'].presence,
                            last_updated: Time.current)
      warnings = process(party)
      raid = @body['raid_id'].present? ? picked_raid : detected_raid
      party.update!(raid: raid, extra: raid.group.extra) if raid
      @options.assign_playlists(party)
    end
    [party, warnings]
  end

  private

  def process(party)
    Rails.logger.info '[IMPORT] Transforming deck data'
    processors = PROCESSORS.map { |klass| klass.new(party, @deck) }
    processors.each(&:process)
    processors.flat_map(&:warnings)
  end

  # The raid the user picked, by id or slug.
  def picked_raid
    Raid.find_by(id: @body['raid_id']) || Raid.find_by(slug: @body['raid_id'])
  end

  # The raid the deck's size points to:
  # - 10 weapons and 5 characters: Farming
  # - 13 weapons and 5 characters: Farming (V2)
  # - 13 weapons and 7 characters: an Unlimited raid
  def detected_raid
    weapons = @deck.dig('deck', 'pc', 'weapons')&.size.to_i
    characters = @deck.dig('deck', 'npc')&.size.to_i

    if weapons == 10 && characters == 5
      Raid.find_by(slug: 'farming')
    elsif weapons == 13 && characters == 5
      Raid.find_by(slug: 'farming-v2')
    elsif weapons == 13 && characters == 7
      Raid.joins(:group).find_by(raid_groups: { unlimited: true })
    end
  end
end
