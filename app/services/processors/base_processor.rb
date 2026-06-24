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
    end

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
