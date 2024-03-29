# frozen_string_literal: true

module Api
  module V1
    class IncompatibleSkillError < GranblueError
      def initialize(data)
        @data = data
      end

      def http_status
        422
      end

      def code
        'incompatible_skill'
      end

      def message
        'The selected skill cannot be added to the current job'
      end

      def to_hash
        {
          message: message,
          code: code,
          job: @data[:job],
          skill: @data[:skill]
        }
      end
    end
  end
end
