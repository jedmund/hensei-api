# frozen_string_literal: true

module Api
  module V1
    class SameFavoriteUserError < GranblueError
      def code
        'same_favorite_user'
      end

      def message
        'Users cannot favorite their own parties'
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
