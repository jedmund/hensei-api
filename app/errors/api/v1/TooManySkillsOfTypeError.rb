# frozen_string_literal: true

module Api
  module V1
    class TooManySkillsOfTypeError < StandardError
      def initialize(data)
        @data = data
      end

      def http_status
        422
      end

      def code
        'too_many_skills_of_type'
      end

      def message
        'You can only have up to 2 skills of type'
      end

      def to_hash
        {
          message: message,
          code: code,
          skill_type: @data[:skill_type]
        }
      end
    end
  end
end
