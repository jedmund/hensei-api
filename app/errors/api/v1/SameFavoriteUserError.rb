module Api::V1
    class SameFavoriteUserError < StandardError
        def http_status
            422
        end

        def code
            "same_favorite_user"
        end

        def message
            "Users cannot favorite their own parties"
        end

        def to_hash
            {
                message: message,
                code: code
            }
        end
    end
end
