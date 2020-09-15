module Api
    class ApplicationController < ActionController::API
        include Doorkeeper::Rails::Helpers

        rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity_response
        rescue_from ActiveRecord::RecordNotDestroyed, with: :render_unprocessable_entity_response
        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response
        rescue_from ActiveRecord::RecordNotSaved, with: :render_unprocessable_entity_response
        rescue_from ActiveRecord::RecordNotUnique, with: :render_unprocessable_entity_response
        rescue_from ActionController::ParameterMissing, with: :render_unprocessable_entity_response

        before_action :current_user

        # Assign the current user if the Doorkeeper token isn't nil
        def current_user
            @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
            return @current_user
        end

        ### Error response methods
        def render_unprocessable_entity_response(exception)
            @exception = exception
            render action: 'errors', status: :unprocessable_entity
        end

        def render_not_found_response(exception)
            response = { errors: [{ message: "Record could not be found.", code: "not_found" }]}
            render 'not_found', status: :not_found
        end

        def render_unauthorized_response(exception)
            render action: 'errors', status: :unauthorized
        end

    end
end