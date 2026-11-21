# frozen_string_literal: true

module Api
  module V1
    ##
    # A user's Wonders. Reads take the user from the path and follow their
    # collection privacy; writes act on the current user's rows only, and
    # never take a user_id from params.
    class CollectionWondersController < ApiController
      WRITE_FIELDS = %i[active level evolution possession].freeze

      before_action :set_target_user, only: %i[index]
      before_action :check_collection_access, only: %i[index]
      before_action :restrict_access, only: %i[create update destroy import]
      before_action :set_collection_wonder, only: %i[update destroy]

      limit_requests 'wonders-import', to: 30, within: 1.minute, only: :import,
                                       by: -> { current_user&.id || client_ip }

      rescue_from ActiveRecord::RecordNotUnique do
        render json: ErrorBlueprint.render_as_json(nil, errors: { wonder_id: ['is already in your collection'] }),
               status: :unprocessable_content
      end

      # GET /users/:user_id/collection/wonders
      def index
        rows = @target_user.collection_wonders.ordered.includes(wonder: :level_bonuses)
        render json: { wonders: CollectionWonderBlueprint.render_as_hash(rows) }
      end

      # POST /collection/wonders
      def create
        attributes = params.expect(collection_wonder: [:wonder_id, *WRITE_FIELDS])
        wonder = Wonder.find_by(id: attributes[:wonder_id])
        return render_not_found_response('wonder') unless wonder

        row = current_user.collection_wonders.build(attributes.except(:wonder_id).merge(wonder: wonder))
        if row.save
          render json: CollectionWonderBlueprint.render(row), status: :created
        else
          render_validation_error_response(row)
        end
      end

      # PUT /collection/wonders/:id
      def update
        if @collection_wonder.update(params.expect(collection_wonder: WRITE_FIELDS))
          render json: CollectionWonderBlueprint.render(@collection_wonder)
        else
          render_validation_error_response(@collection_wonder)
        end
      end

      # DELETE /collection/wonders/:id
      def destroy
        @collection_wonder.destroy
        head :no_content
      end

      # POST /collection/wonders/import { data: [<memorial_list category>…], lang: 'en' | 'ja' }
      #
      # data is the raw response array, read from the request body as is
      # (strong params can't take a top-level array of arbitrary objects).
      # lang is informational.
      def import
        data = request.request_parameters['data']
        return render json: { error: 'No data provided' }, status: :bad_request if data.blank?

        result = WonderCollectionImport.new(current_user, data).call
        render json: result.as_json
      rescue WonderCollectionImport::InvalidPayload => e
        render json: { error: e.message }, status: :bad_request
      end

      private

      def set_target_user
        @target_user = User.find(params.expect(:user_id))
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def check_collection_access
        return if @target_user.nil?
        return if @target_user.collection_viewable_by?(current_user)

        render json: { error: 'You do not have permission to view this collection' }, status: :forbidden
      end

      def set_collection_wonder
        @collection_wonder = current_user.collection_wonders.includes(wonder: %i[level_bonuses evolution_caps])
                                         .find(params.expect(:id))
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('wonder', params[:id])
      end
    end
  end
end
