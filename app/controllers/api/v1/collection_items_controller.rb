# frozen_string_literal: true

module Api
  module V1
    # Shared actions for the character, weapon and summon collection endpoints.
    #
    # Reads (index, show) look up the collection's owner from the URL and check
    # their privacy setting. Writes require a signed-in user and only ever touch
    # that user's own collection, so a record is always authorized against its
    # real owner.
    #
    # Each subclass declares its type with +collection_item+, which builds a
    # frozen ItemType. Index filtering and sorting live in CollectionItemQuery.
    # Subclasses override a method only for behavior that isn't data: see
    # assign_item_attributes and render_create_error.
    class CollectionItemsController < ApiController
      # Everything that differs between collection types as data.
      ItemType = Data.define(
        :type, :catalog, :blueprint, :catalog_blueprint, :catalog_view, :import_service, :permitted,
        :owned_includes, :unowned_includes, :owned_filters, :unowned_filters, :proficiency_column,
        :unique_per_user
      ) do
        def self.deep_freeze(value)
          case value
          when Hash then value.to_h { |key, item| [key, deep_freeze(item)] }.freeze
          when Array then value.map { |item| deep_freeze(item) }.freeze
          else value
          end
        end

        def initialize(**attributes)
          super(**attributes.transform_values { |value| self.class.deep_freeze(value) })
        end

        def association = :"collection_#{type}s"
        def param_key = :"collection_#{type}"
        def foreign_key = :"#{type}_id"
        def root = :"#{type}s"
      end

      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_item_for_read, only: :show
      before_action :restrict_access, except: %i[index show]
      before_action :set_item_for_write, only: %i[update destroy]

      class << self
        attr_reader :item_type

        # Declares the collection type this controller serves.
        #
        # @param type [Symbol] :character, :weapon or :summon
        # @param catalog [Class] the catalog model (Character, Weapon, Summon)
        # @param blueprint [Class] the collection item blueprint
        # @param catalog_blueprint [Class] the blueprint for unowned catalog rows
        # @param catalog_view [Symbol] the catalog blueprint view
        # @param import_service [Class] the game-data import service
        # @param permitted [Array] attributes a user may set on an item
        # @param owned_includes [Array, Hash, Symbol] preloads for owned items
        # @param unowned_includes [Array, Hash, Symbol] preloads for unowned catalog rows
        # @param owned_filters [Hash] type-specific filters on owned items (see CollectionItemQuery)
        # @param unowned_filters [Hash] type-specific filters on unowned catalog rows
        # @param proficiency_column [Symbol, nil] catalog column the unowned
        #   proficiency sort uses; nil when the type has no proficiency
        # @param unique_per_user [Boolean] whether a user owns at most one of each
        #   item; a batch then skips items already owned
        def collection_item(type, catalog:, blueprint:, catalog_blueprint:, catalog_view:, import_service:, permitted:,
                            owned_includes:, unowned_includes:, owned_filters: {}, unowned_filters: {},
                            proficiency_column: nil, unique_per_user: false)
          @item_type = ItemType.new(
            type:, catalog:, blueprint:, catalog_blueprint:, catalog_view:, import_service:, permitted:,
            owned_includes:, unowned_includes:, owned_filters:, unowned_filters:, proficiency_column:,
            unique_per_user:
          )
        end
      end

      def index
        query = CollectionItemQuery.new(item_type, owner: @target_user, params:, viewer: current_user)
        if params[:unowned].present?
          render_unowned_index(query.unowned)
        else
          render_owned_index(query.owned)
        end
      end

      def show
        render json: item_type.blueprint.render(@collection_item, view: :full)
      end

      def create
        @collection_item = current_user_items.build(item_params)

        if @collection_item.save
          render json: item_type.blueprint.render(@collection_item, view: :full), status: :created
        else
          render_create_error(@collection_item)
        end
      end

      def update
        assign_item_attributes(@collection_item, item_params)

        if @collection_item.save
          render json: item_type.blueprint.render(@collection_item, view: :full)
        else
          render_validation_error_response(@collection_item)
        end
      end

      def destroy
        @collection_item.destroy
        head :no_content
      end

      # POST /collection/:type/batch
      # Creates several items in one request. Items that fail validation are
      # reported in meta.errors and answered with 207. For types a user owns
      # at most one of, items already owned are skipped.
      def batch
        created = []
        skipped = []
        errors = []
        items = batch_items
        owned = owned_keys(items)

        ActiveRecord::Base.transaction do
          items.each_with_index do |attrs, index|
            if owned&.include?(attrs[foreign_key].to_s)
              skipped << { index:, foreign_key => attrs[foreign_key], reason: 'already_exists' }
              next
            end

            item = current_user_items.build(attrs)
            if item.save
              owned&.add(item.public_send(foreign_key).to_s)
              created << item
            else
              errors << { index:, foreign_key => attrs[foreign_key], error: item.errors.full_messages.join(', ') }
            end
          end
        end

        render json: item_type.blueprint.render(
          created,
          root: item_type.root,
          meta: batch_meta(created, skipped, errors)
        ), status: errors.any? ? :multi_status : :created
      end

      # DELETE /collection/:type/batch_destroy
      # Deletes the signed-in user's items with the given ids; other ids are ignored.
      def batch_destroy
        ids = params.permit(ids: [])[:ids] || []
        deleted_count = current_user_items.where(id: ids).destroy_all.count

        render json: { meta: { deleted: deleted_count } }, status: :ok
      end

      # POST /collection/:type/import
      # Imports items from game JSON data.
      #
      # @param data [Hash] Game data containing the item list
      # @param update_existing [Boolean] Whether to update items already owned (default: false)
      def import
        options = import_params
        return render_missing_data if options[:data].blank?

        result = item_type.import_service.new(current_user, options[:data], **import_options(options)).import

        render json: import_summary(result), status: result.success? ? :created : :multi_status
      end

      # POST /collection/:type/check_updates
      # Returns field-level diffs for owned items that the import would change.
      # Items the user doesn't own are skipped.
      #
      # @param data [Hash] Game data containing the item list
      def check_updates
        game_data = import_params[:data]
        return render_missing_data if game_data.blank?

        render json: { updates: item_type.import_service.new(current_user, game_data).preview_updates }
      end

      private

      def item_type
        self.class.item_type
      end

      # --- Behavior subclasses may override ---

      def assign_item_attributes(item, attrs)
        item.assign_attributes(attrs)
      end

      def render_create_error(item)
        render_validation_error_response(item)
      end

      # --- Import (CollectionInventorySync extends these) ---

      def import_params
        { update_existing: params[:update_existing], data: params[:data]&.to_unsafe_h }
      end

      def import_options(options)
        { update_existing: options[:update_existing] == true }
      end

      def import_summary(result)
        {
          success: result.success?,
          created: result.created.size,
          updated: result.updated.size,
          skipped: result.skipped.size,
          errors: result.errors
        }
      end

      # --- Index ---

      def render_owned_index(items)
        items = items.paginate(page: params[:page], per_page: collection_page_size)

        render json: item_type.blueprint.render(items, root: item_type.root, meta: pagination_meta(items))
      end

      def render_unowned_index(catalog)
        catalog = catalog.paginate(page: params[:page], per_page: collection_page_size)

        render json: item_type.catalog_blueprint.render(
          catalog,
          view: item_type.catalog_view,
          root: item_type.root,
          meta: pagination_meta(catalog)
        )
      end

      # --- Batch ---

      # For types a user owns at most one of: the ids the user already owns
      # among the items, in one query (nil for other types)
      def owned_keys(items)
        return unless item_type.unique_per_user

        ids = items.filter_map { |attrs| attrs[foreign_key].presence }
        current_user_items.where(foreign_key => ids).pluck(foreign_key).to_set(&:to_s)
      end

      def batch_meta(created, skipped, errors)
        return { created: created.size, errors: errors } unless item_type.unique_per_user

        { created: created.size, skipped: skipped.size, skipped_items: skipped, errors: errors }
      end

      # --- Lookups ---

      def set_target_user
        @target_user = User.find(params.expect(:user_id))
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'User not found' }, status: :not_found
      end

      def check_collection_access
        return if @target_user.nil? # Already handled by set_target_user
        return if @target_user.collection_viewable_by?(current_user)

        render json: { error: 'You do not have permission to view this collection' }, status: :forbidden
      end

      def set_item_for_read
        @collection_item = find_item(@target_user.public_send(item_type.association))
      end

      def set_item_for_write
        @collection_item = find_item(current_user_items)
      end

      def find_item(scope)
        scope.find(params.expect(:id))
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new(item_type.type.to_s, params[:id])
      end

      def current_user_items
        current_user.public_send(item_type.association)
      end

      # --- Params ---

      def item_params
        params.expect(item_type.param_key => item_type.permitted)
      end

      def batch_items
        params.permit(item_type.association => item_type.permitted)[item_type.association] || []
      end

      def foreign_key
        item_type.foreign_key
      end

      def render_missing_data
        render json: { error: 'No data provided' }, status: :bad_request
      end
    end
  end
end
