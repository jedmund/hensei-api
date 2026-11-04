# frozen_string_literal: true

module CollectionImport
  ##
  # Shared flow for importing a user's game inventory into one collection.
  #
  # Each import service declares its type with +collection_import+, which
  # builds a frozen Config, and supplies what differs per type as methods:
  # find_catalog, build_attrs, item_ref and skip_entry. This class runs the
  # items in one transaction, sorts each into created, updated, skipped or
  # errors, and builds the Result. A failing item is recorded and the others
  # still import.
  #
  # Inventory adds the per-copy game_id flow (weapons, summons, artifacts);
  # CharacterImportService builds on this class directly.
  class Base
    Result = Struct.new(:success?, :created, :updated, :skipped, :errors, :reconciliation, keyword_init: true)

    # Everything that differs between import types as data.
    Config = Data.define(:type, :grid_model) do
      def association = :"collection_#{type}s"
      def foreign_key = :"#{type}_id"
      def grid_foreign_key = :"collection_#{type}_id"
      def not_found_message = "#{type.to_s.capitalize} not found"
      def empty_message = "No #{type} items found in data"
    end

    # Clamps for the game's evolution (uncap stars) and phase (transcendence stage).
    GAME_UNCAP_RANGE = (0..5)
    GAME_PHASE_RANGE = (0..10)
    TRANSCENDED_UNCAP_LEVEL = 6

    class << self
      attr_reader :config

      # Declares the collection type this service imports.
      #
      # @param type [Symbol] :character, :weapon, :summon or :artifact
      # @param grid_model [Class, nil] the grid item linked to a collection copy;
      #   reconciliation lists the ones a deletion orphans
      def collection_import(type, grid_model: nil)
        @config = Config.new(type:, grid_model:)
      end
    end

    # @param user [User] the user whose collection is written
    # @param game_data [Hash, Array] the game's items, as a list or under 'list'
    # @param options [Hash] update_existing: update items already owned
    def initialize(user, game_data, options = {})
      @user = user
      @game_data = game_data
      @update_existing = options[:update_existing] || false
      @created = []
      @updated = []
      @skipped = []
      @errors = []
    end

    ##
    # Imports the items into the user's collection.
    #
    # @return [Result] the created, updated and skipped records and the errors
    def import
      items = extract_items
      return empty_result if items.empty?

      prepare(items)
      ActiveRecord::Base.transaction do
        items.each_with_index do |item, index|
          import_item(item)
        rescue StandardError => e
          @errors << { index: index, game_id: failed_game_id(item), error: e.message }
        end
      end

      Result.new(success?: @errors.empty?, created: @created, updated: @updated, skipped: @skipped,
                 errors: @errors, reconciliation: reconciliation)
    end

    private

    def config
      self.class.config
    end

    def collection
      @user.public_send(config.association)
    end

    def extract_items
      return @game_data if @game_data.is_a?(Array)
      return @game_data['list'] if @game_data.is_a?(Hash) && @game_data['list'].is_a?(Array)

      []
    end

    def empty_result
      Result.new(success?: false, created: [], updated: [], skipped: [], errors: [config.empty_message],
                 reconciliation: nil)
    end

    # --- Hooks a type may override ---

    # Runs once before the items, e.g. to preload lookups.
    def prepare(_items); end

    # The deletions a full sync made, or nil.
    def reconciliation; end

    # The game id recorded when an item raises.
    def failed_game_id(item)
      item.dig('param', 'id')
    end

    # --- Writing ---

    # Creates the item, updates the owned copy when asked, or skips it.
    #
    # @param existing [ActiveRecord::Base, nil] the user's copy of the item
    # @param update [Boolean] whether an owned copy is updated or skipped
    def save_item(item, catalog, existing, update: @update_existing)
      if existing.nil?
        create_record(build_attrs(item, catalog), item_ref(item, catalog))
      elsif update
        update_record(existing, build_attrs(item, catalog), item_ref(item, catalog))
      else
        @skipped << skip_entry(item, catalog, 'Already exists')
      end
    end

    def create_record(attrs, ref)
      record = collection.build(attrs)
      return @created << record if record.save

      record_failure(record, ref)
    end

    def update_record(record, attrs, ref)
      return @updated << record if record.update(attrs)

      record_failure(record, ref)
    end

    def record_failure(record, ref)
      @errors << ref.merge(error: record.errors.full_messages.join(', '))
    end

    def record_not_found(item)
      @errors << item_ref(item).merge(error: config.not_found_message)
    end

    # --- Game encoding ---

    # The game's evolution and phase as our uncap_level and transcendence_step.
    # A transcended item (phase above 0 at 5 stars) has uncap level 6.
    #
    # @param max_transcendence [Integer] a lower ceiling for the step, e.g. a
    #   character's released stage
    # @return [Hash] uncap_level and transcendence_step
    def game_uncap(evolution, phase, max_transcendence: GAME_PHASE_RANGE.max)
      uncap = evolution.to_i.clamp(GAME_UNCAP_RANGE)
      transcendence = [phase.to_i.clamp(GAME_PHASE_RANGE), max_transcendence].min
      uncap = TRANSCENDED_UNCAP_LEVEL if transcendence.positive? && uncap >= GAME_UNCAP_RANGE.max

      { uncap_level: uncap, transcendence_step: transcendence }
    end
  end
end
