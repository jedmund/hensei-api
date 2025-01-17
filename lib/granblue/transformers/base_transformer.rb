# frozen_string_literal: true

module Granblue
  module Transformers
    class TransformerError < StandardError
      attr_reader :details

      def initialize(message, details = nil)
        @details = details
        super(message)
      end
    end

    class BaseTransformer
      ELEMENT_MAPPING = {
        0 => nil,
        1 => 4, # Wind -> Earth
        2 => 2, # Fire -> Fire
        3 => 3, # Water -> Water
        4 => 1, # Earth -> Wind
        5 => 6, # Dark -> Light
        6 => 5 # Light -> Dark
      }.freeze

      def initialize(data, options = {})
        @data = data
        @options = options
        @language = options[:language] || 'en'
        Rails.logger.info "[TRANSFORM] Initializing #{self.class.name} with data: #{data.class}"
        validate_data
      end

      def transform
        raise NotImplementedError, "#{self.class} must implement #transform"
      end

      protected

      attr_reader :data, :options, :language

      def validate_data
        Rails.logger.info "[TRANSFORM] Validating data: #{data.inspect[0..100]}..."

        if data.nil?
          Rails.logger.info "[TRANSFORM] Data is nil"
          return true
        end

        if data.empty?
          Rails.logger.info "[TRANSFORM] Data is empty"
          return true
        end

        # Data validation successful
        true
      end

      def get_master_param(obj)
        return [nil, nil] unless obj.is_a?(Hash)

        master = obj['master']
        param = obj['param']
        Rails.logger.debug "[TRANSFORM] Extracted master: #{!!master}, param: #{!!param}"

        [master, param]
      end

      def log_debug(message)
        return unless options[:debug]
        Rails.logger.debug "[TRANSFORM-DEBUG] #{self.class.name}: #{message}"
      end
    end
  end
end
