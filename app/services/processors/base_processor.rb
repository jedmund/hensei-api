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
    # Logs a message to Rails.logger.
    #
    # @param message [String] the message to log.
    # @return [void]
    def log(message)
      Rails.logger.info "[PROCESSOR][#{self.class.name}] #{message}"
    end
  end
end
