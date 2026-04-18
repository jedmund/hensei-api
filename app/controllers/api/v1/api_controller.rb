# frozen_string_literal: true

module Api
  module V1
    class ApiController < ActionController::API
      ##### Doorkeeper
      include Doorkeeper::Rails::Helpers

      ##### Constants
      COLLECTION_PER_PAGE = 15
      SEARCH_PER_PAGE = 10
      MAX_PER_PAGE = 100
      MIN_PER_PAGE = 1

      ##### Errors
      # Catch-all for unhandled exceptions - log details and return 500
      # NOTE: Must be defined FIRST so it's checked LAST (Rails matches bottom-to-top)
      rescue_from StandardError do |e|
        Rails.logger.error "[500 Error] #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace&.first(20)&.join("\n")
        render json: { error: 'Internal Server Error', message: e.message }, status: :internal_server_error
      end

      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity_response
      rescue_from ActiveRecord::RecordNotDestroyed, with: :render_unprocessable_entity_response
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response_without_object
      rescue_from ActiveRecord::RecordNotSaved, with: :render_unprocessable_entity_response
      rescue_from ActiveRecord::RecordNotUnique, with: :render_unprocessable_entity_response
      rescue_from Api::V1::FavoriteAlreadyExistsError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::NoJobProvidedError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::TooManySkillsOfTypeError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::IncompatibleWeaponForPositionError, with: :render_unprocessable_entity_response
      rescue_from Api::V1::UnauthorizedError, with: :render_unauthorized_response
      rescue_from ActionController::ParameterMissing, with: :render_unprocessable_entity_response

      # Collection errors
      rescue_from CollectionErrors::CollectionError do |e|
        render json: e.to_hash, status: e.http_status
      end

      # Crew errors
      rescue_from CrewErrors::CrewError do |e|
        render json: e.to_hash, status: e.http_status
      end

      # Party share errors
      rescue_from PartyShareErrors::PartyShareError do |e|
        render json: e.to_hash, status: e.http_status
      end

      rescue_from GranblueError do |e|
        render_error(e)
      end

      rescue_from Api::V1::GranblueError do |e|
        render_error(e)
      end

      ##### Hooks
      before_action :current_user
      before_action :default_content_type
      around_action :n_plus_one_detection, if: -> { Rails.env.development? }

      ##### Responders
      respond_to :json

      ##### Methods
      # Returns the latest version for each update type
      def version
        latest_updates = AppUpdate
                         .select('DISTINCT ON (update_type) update_type, version, updated_at')
                         .order(:update_type, updated_at: :desc)

        result = latest_updates.each_with_object({}) do |update, hash|
          hash[update.update_type] = {
            version: update.version,
            updated_at: update.updated_at
          }
        end

        render json: result
      end

      # Assign the current user if the Doorkeeper token isn't nil, then
      # update the current user's last seen datetime and last IP address
      # before returning
      def current_user
        @current_user ||= User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token

        @current_user
      end

      def admin_mode
        if current_user&.admin? && request.headers['X-Admin-Mode']
          @admin_mode ||= request.headers['X-Admin-Mode'] == 'true'
        end

        @admin_mode
      end

      def edit_key
        @edit_key ||= request.headers['X-Edit-Key'] if request.headers['X-Edit-Key']

        @edit_key
      end

      # Set the response content-type
      def content_type(content_type)
        response.headers['Content-Type'] = content_type
      end

      # Set the default response content-type
      def default_content_type
        content_type('application/json; charset=utf-8')
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
        error_data = if exception.respond_to?(:to_hash)
                       exception.to_hash
                     elsif exception.is_a?(ActionController::ParameterMissing)
                       { message: exception.message, param: exception.param }
                     elsif exception.respond_to?(:message)
                       { message: exception.message }
                     else
                       exception
                     end

        render json: ErrorBlueprint.render_as_json(nil, errors: error_data),
               status: :unprocessable_entity
      end

      def render_validation_error_response(object)
        render json: ErrorBlueprint.render_as_json(nil, errors: object.errors),
               status: :unprocessable_entity
      end

      def render_not_found_response_without_object
        render json: ErrorBlueprint.render(nil,
                                           error: {
                                             message: 'Object could not be found',
                                             code: 'not_found'
                                           }), status: :not_found
      end

      def render_not_found_response(object)
        render json: ErrorBlueprint.render(nil, error: {
          message: "#{object.capitalize} could not be found",
          code: 'not_found'
        }), status: :not_found
      end

      def render_unauthorized_response
        render json: ErrorBlueprint.render_as_json(nil),
               status: :unauthorized
      end

      def render_forbidden_response(message = 'Forbidden')
        render json: ErrorBlueprint.render(nil, error: {
          message: message,
          code: 'forbidden'
        }), status: :forbidden
      end

      private

      def restrict_access
        raise UnauthorizedError unless current_user
      end

      # Returns the requested page size within valid bounds
      # Falls back to default if not specified or invalid
      # Reads from X-Per-Page header
      def page_size(default = COLLECTION_PER_PAGE)
        per_page_header = request.headers['X-Per-Page']
        return default unless per_page_header.present?

        requested_size = per_page_header.to_i
        return default if requested_size <= 0

        [[requested_size, MAX_PER_PAGE].min, MIN_PER_PAGE].max
      end

      # Returns the requested page size for search operations
      def search_page_size
        page_size(SEARCH_PER_PAGE)
      end

      # Returns a clamped page size from the `limit` query parameter
      def collection_page_size(default = 50)
        raw = params[:limit]
        return default unless raw.present?

        requested = raw.to_i
        return default if requested <= 0

        [[requested, MAX_PER_PAGE].min, MIN_PER_PAGE].max
      end

      def n_plus_one_detection
        Prosopite.scan
        yield
      ensure
        Prosopite.finish
      end

      # Returns pagination metadata for will_paginate collections
      # @param collection [ActiveRecord::Relation] Paginated collection using will_paginate
      # @return [Hash] Pagination metadata with count, total_pages, and per_page
      def pagination_meta(collection)
        {
          count: collection.total_entries,
          total_pages: collection.total_pages,
          per_page: collection.limit_value || collection.per_page
        }
      end
    end
  end
end
