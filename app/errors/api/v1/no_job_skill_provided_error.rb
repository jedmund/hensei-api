# frozen_string_literal: true

module Api
  module V1
    class NoJobSkillProvidedError < GranblueError
      def http_status
        422
      end

      def code
        'no_job_skill_provided'
      end

      def message
        'A job skill ID must be provided'
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
