# frozen_string_literal: true

module Api
  module V1
    class ApiController < ActionController::API
      ##### Doorkeeper
      include Doorkeeper::Rails::Helpers

      ##### Errors
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity_response
      rescue_from ActiveRecord::RecordNotDestroyed, with: :render_unprocessable_entity_response
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response
      rescue_from ActiveRecord::RecordNotSaved, with: :render_unprocessable_entity_response
      rescue_from ActiveRecord::RecordNotUnique, with: :render_unprocessable_entity_response
      rescue_from Api::V1::SameFavoriteUserError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::FavoriteAlreadyExistsError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::NoJobProvidedError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::TooManySkillsOfTypeError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::UnauthorizedError, with: :render_unauthorized_response
      rescue_from ActionController::ParameterMissing, with: :render_unprocessable_entity_response

      rescue_from GranblueError do |e|
        render_error(e)
      end

      ##### Hooks
      before_action :current_user
      before_action :set_default_content_type

      ##### Responders
      respond_to :json

      ##### Methods
      # Assign the current user if the Doorkeeper token isn't nil, then
      # update the current user's last seen datetime and last IP address
      # before returning
      def current_user
        @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token

        @current_user
      end

      # Set the response content-type
      def set_content_type(content_type)
        response.headers['Content-Type'] = content_type
      end

      # Set the default response content-type to application/javascript
      # with a UTF-8 charset
      def set_default_content_type
        set_content_type('application/javascript; charset=utf-8')
      end

      ### Error response methods
      def render_error(error)
        if error
          render action: 'errors', json: error.to_hash, status: error.http_status
        else
          render action: 'errors'
        end
      end

      def render_unprocessable_entity_response(exception)
        @exception = exception
        render action: 'errors', status: :unprocessable_entity
      end

      def render_validation_error_response(object)
        render json: ErrorBlueprint.render_as_json(nil, errors: object.errors),
               status: :unprocessable_entity
      end

      def render_not_found_response(object)
        render json: ErrorBlueprint.render(nil, error: {
                                             message: "#{object.capitalize} could not be found",
                                             code: 'not_found'
                                           }), status: :not_found
      end

      def render_unauthorized_response
        render action: 'errors', status: :unauthorized
      end

      private

      def restrict_access
        raise UnauthorizedError unless current_user
      end
    end
  end
end
