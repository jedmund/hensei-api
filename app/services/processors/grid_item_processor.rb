# frozen_string_literal: true

module Processors
  ##
  # Shared flow for the deck processors that build grid items (characters,
  # summons, weapons).
  #
  # Each processor declares its type with +grid_item+, which builds a frozen
  # Config, and supplies what differs per type as methods: build_items (the
  # unsaved grid items for the deck) and, optionally, game_customizations (what
  # else the game shows that the collection copy should take). This class checks
  # the deck, saves each item, raises the linked collection copy to what the game
  # shows and syncs the item back from it. An item that fails validation is
  # skipped and the others still import.
  #
  # @abstract
  class GridItemProcessor < BaseProcessor
    # Everything that differs between grid item types as data.
    Config = Data.define(:type, :deck_path, :association) do
      def log_tag = type.to_s.upcase
      def grid_model = :"Grid#{type.to_s.camelize}"
      def foreign_key = :"#{type}_id"
      def collection_key = :"collection_#{type}"
      def collection_association = :"collection_#{type}s"
    end

    # Levels at each transcendence step (step 0 is level 200).
    TRANSCENDENCE_LEVELS = [200, 210, 220, 230, 240, 250].freeze

    class << self
      attr_reader :config

      # Declares the grid item type this processor builds.
      #
      # @param type [Symbol] :character, :summon or :weapon
      # @param deck_path [Array<String>] keys that must be in the deck JSON
      # @param association [Symbol] the party association that holds the items
      def grid_item(type, deck_path:, association:)
        @config = Config.new(type:, deck_path: deck_path.freeze, association:)
      end
    end

    ##
    # @param party [Party] the Party record.
    # @param data [Hash] the deck hash.
    # @param _type [Symbol] unused; kept for the shared processor signature.
    # @param options [Hash] additional options.
    def initialize(party, data, _type = :normal, options = {})
      super(party, data, options)
    end

    ##
    # Builds the grid items from the deck and saves them.
    #
    # @return [void]
    def process
      return unless deck_present?

      @data = @data.with_indifferent_access
      build_items.each { |item| save_item(item) }
    end

    private

    def config = self.class.config

    # @abstract
    # @return [Array<ActiveRecord::Base>] the unsaved grid items
    def build_items
      raise NotImplementedError, "#{self.class} must implement build_items"
    end

    def deck_present?
      unless @data.is_a?(Hash)
        log_error "Invalid data format: expected a Hash, got #{@data.class}"
        return false
      end

      node = @data
      return true if config.deck_path.all? { |key| node.key?(key).tap { node = node[key] } }

      log_error missing_data_message
      false
    end

    def missing_data_message = "Missing #{config.deck_path.last} data in deck JSON"

    # A deck slot the game left empty, or sent without its master or param data.
    def incomplete?(raw)
      raw.nil? || raw['param'].nil? || raw['master'].nil?
    end

    def save_item(item)
      item.save!
      return if item.public_send(config.collection_key).blank?

      update_collection_from_game(item)
      sync_from_collection(item)
    rescue ActiveRecord::RecordInvalid => e
      retry if retry_save?(item, e)

      skip_item(item, e)
    end

    # Whether to try saving an invalid item again after changing it.
    def retry_save?(_item, _error) = false

    def skip_item(item, error)
      log_error "Failed to create #{config.grid_model}: #{error.record.errors.full_messages.join(', ')}"
      add_warning('item_skipped', item, item.public_send(config.type))
      discard_unsaved(item, config.association)
    end

    def sync_from_collection(item)
      item.sync_from_collection!
    rescue ActiveRecord::RecordInvalid => e
      log_error "Sync from collection failed, reverting: #{e.record.errors.full_messages.join(', ')}"
      item.reload
    end

    ##
    # Updates the linked collection copy from the game, the source of truth: a
    # higher uncap or transcendence, and the type's game_customizations, so that
    # sync_from_collection! round-trips them.
    def update_collection_from_game(item)
      copy = item.public_send(config.collection_key)
      return unless copy.public_send(config.foreign_key) == item.public_send(config.foreign_key)

      updates = raised_uncap(item, copy).merge(game_customizations(item))
      return if updates.empty?

      copy.update!(updates)
      log_info "Updated collection #{config.type} #{copy.id} from game data: #{updates}"
    rescue ActiveRecord::RecordInvalid => e
      log_warn "Could not update collection #{config.type} #{copy.id}: #{e.record.errors.full_messages.join(', ')}"
    end

    def raised_uncap(item, copy)
      %i[uncap_level transcendence_step].each_with_object({}) do |attr, updates|
        updates[attr] = item[attr] if item[attr] > copy[attr]
      end
    end

    # @return [Hash] what else the collection copy takes from the game
    def game_customizations(_item) = {}

    ##
    # Links the grid item to the user's collection copy found by +lookup+,
    # creating one from +lookup+ and +attrs+ when the user imports to their
    # collection.
    def link_collection(item, lookup, attrs)
      copies = @party.user.public_send(config.collection_association)
      copy = copies.find_by(lookup)
      copy ||= create_collection_copy(copies, lookup.merge(attrs)) if @party.user.import_weapons
      item.public_send(:"#{config.collection_key}=", copy) if copy
    end

    def create_collection_copy(copies, attrs)
      copies.create!(attrs)
    rescue StandardError => e
      log_error "Failed to create collection #{config.type} during import: #{e.message}"
      nil
    end

    ##
    # Converts a level, rounded down to the nearest 10, to its transcendence
    # step: 0 below 200 and past the known levels, 5 at 250.
    #
    # @param level [Integer]
    # @return [Integer]
    def level_to_transcendence(level)
      return 0 if level < 200

      floored_level = (level / 10).floor * 10
      TRANSCENDENCE_LEVELS.index(floored_level) || 0
    end

    def log_info(message) = Rails.logger.info("[#{config.log_tag}] #{message}")
    def log_warn(message) = Rails.logger.warn("[#{config.log_tag}] #{message}")
    def log_error(message) = Rails.logger.error("[#{config.log_tag}] #{message}")
  end
end
