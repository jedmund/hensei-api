# frozen_string_literal: true

module Api
  module V1
    class UnauthorizedError < StandardError
      def http_status
        401
      end

      def code
        'unauthorized'
      end

      def message
        'User is not allowed to modify that resource'
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
