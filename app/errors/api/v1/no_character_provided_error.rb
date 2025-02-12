# frozen_string_literal: true

module Api
  module V1
    class NoCharacterProvidedError < GranblueError
      def http_status
        422
      end

      def code
        'no_character_provided'
      end

      def message
        'A valid character must be provided'
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
