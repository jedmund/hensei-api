# frozen_string_literal: true

module Api
  module V1
    class InvalidPositionError < GranblueError
      def code
        'invalid_position'
      end

      def message
        @data || 'Invalid position specified'
      end
    end
  end
end