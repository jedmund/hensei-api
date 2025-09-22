# frozen_string_literal: true

module Api
  module V1
    class PartyDeletionFailedError < StandardError
      attr_reader :errors

      def initialize(errors = [])
        @errors = errors
        super(message)
      end

      def http_status
        422
      end

      def code
        'party_deletion_failed'
      end

      def message
        if @errors.any?
          "Failed to delete party: #{@errors.join(', ')}"
        else
          'Failed to delete party due to an unknown error'
        end
      end

      def to_hash
        {
          message: message,
          code: code,
          errors: @errors
        }
      end
    end
  end
end