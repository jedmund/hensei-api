# frozen_string_literal: true

module Api
  module V1
    # This is the base error that we inherit from for application errors
    class GranblueError < StandardError
      def initialize(data = '')
        @data = data
        super(message)
      end

      def http_status
        422
      end

      def code
        'granblue_error'
      end

      def message
        @data.presence || 'Something went wrong'
      end

      def to_hash
        {
          message: message,
          code: code
        }
      end
    end
  end
end
