# frozen_string_literal: true

module Api
  module V1
    class IncompatibleWeaponForPositionError < GranblueError
      def http_status
        422
      end

      def code
        'incompatible_weapon_for_position'
      end

      def message
        'A weapon of this series cannot be added to Additional Weapons'
      end

      def to_hash
        {
          message: message,
          code: code,
          weapon: @data[:weapon]
        }
      end
    end
  end
end
