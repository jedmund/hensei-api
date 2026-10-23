# frozen_string_literal: true

module Processors
  ##
  # BaseProcessor provides shared functionality for processing transformed deck data
  # into new party records. Subclasses must implement the +process+ method.
  #
  # @abstract
  class BaseProcessor
    ##
    # Initializes the processor.
    #
    # @param party [Party] the Party record to which the component will be added.
    # @param data [Object] the transformed data for this component.
    # @param options [Hash] optional additional options.
    def initialize(party, data, options = {})
      @party = party
      @data = data
      @options = options
      @warnings = []
    end

    # @return [Array<Hash>] non-fatal problems found while processing, e.g. an
    #   item that was skipped. Returned to the client with the import result.
    attr_reader :warnings

    ##
    # Process the given data and create associated records.
    #
    # @abstract Subclasses must implement this method.
    # @return [void]
    def process
      raise NotImplementedError, "#{self.class} must implement the process method"
    end

    protected

    attr_reader :party, :data, :options

    ##
    # Removes a record that failed to save from the party's in-memory association.
    #
    # Grid items built with `party:` are added to the party's has_many target via
    # inverse_of. If one fails validation it stays there unsaved, and the next
    # `party.update!` autosaves it, raises, and rolls back the whole import.
    #
    # @param record [ActiveRecord::Base] the unsaved grid item.
    # @param association [Symbol] the party association that holds it.
    # @return [void]
    def discard_unsaved(record, association)
      return if record.persisted?

      @party.association(association).target.delete(record)
    end

    ##
    # Records a non-fatal problem with a grid item.
    #
    # @param code [String] e.g. 'item_skipped', 'ax_skills_dropped'
    # @param record [GridWeapon, GridSummon] the grid item.
    # @param item [Object, nil] the canonical Weapon/Summon record.
    # @return [void]
    def add_warning(code, record, item)
      @warnings << {
        code: code,
        type: record.class.name.delete_prefix('Grid').downcase,
        position: record.position,
        granblue_id: item&.granblue_id,
        name: item&.name_en,
        details: record.errors.full_messages
      }
    end

    ##
    # Logs a message to Rails.logger, and records it as a Sentry breadcrumb when
    # Sentry is active. Breadcrumbs add zero standalone noise — they only ship
    # attached to an exception that actually gets captured — but give the full
    # processor step trail for the next unexpected import failure.
    #
    # @param message [String] the message to log.
    # @return [void]
    def log(message)
      Rails.logger.info "[PROCESSOR][#{self.class.name}] #{message}"

      return unless defined?(Sentry) && Sentry.initialized?

      Sentry.add_breadcrumb(
        Sentry::Breadcrumb.new(category: 'processor', message: "[#{self.class.name}] #{message}", level: 'info')
      )
    end
  end
end
