# frozen_string_literal: true

module Api
  module V1
    class PositionOccupiedError < GranblueError
      def code
        'position_occupied'
      end

      def message
        @data || 'Position is already occupied'
      end
    end
  end
end