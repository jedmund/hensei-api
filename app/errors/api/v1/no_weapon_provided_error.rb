# frozen_string_literal: true

module Api
  module V1
    class NoWeaponProvidedError < GranblueError
      def http_status
        422
      end

      def code
        'no_weapon_provided'
      end

      def message
        'A valid weapon must be provided'
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
