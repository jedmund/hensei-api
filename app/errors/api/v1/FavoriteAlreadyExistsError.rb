module Api::V1
    class FavoriteAlreadyExistsError < StandardError
        def http_status
            422
        end

        def code
            "favorite_already_exists"
        end

        def message
            "This user has favorited this party already"
        end

        def to_hash
            {
                message: message,
                code: code
            }
        end
    end
end
