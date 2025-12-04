# frozen_string_literal: true

module Api
  module V1
    class AlreadyInCrewError < GranblueError
      def http_status
        422
      end

      def code
        'already_in_crew'
      end

      def message
        'You are already in a crew'
      end
    end

    class CaptainCannotLeaveError < GranblueError
      def http_status
        422
      end

      def code
        'captain_cannot_leave'
      end

      def message
        'Captain must transfer ownership before leaving'
      end
    end

    class CannotRemoveCaptainError < GranblueError
      def http_status
        422
      end

      def code
        'cannot_remove_captain'
      end

      def message
        'Cannot remove the captain from the crew'
      end
    end

    class ViceCaptainLimitError < GranblueError
      def http_status
        422
      end

      def code
        'vice_captain_limit'
      end

      def message
        'Crew can only have up to 3 vice captains'
      end
    end

    class NotInCrewError < GranblueError
      def http_status
        422
      end

      def code
        'not_in_crew'
      end

      def message
        'You are not in a crew'
      end
    end

    class MemberNotFoundError < GranblueError
      def http_status
        404
      end

      def code
        'member_not_found'
      end

      def message
        'Member not found in this crew'
      end
    end
  end
end
