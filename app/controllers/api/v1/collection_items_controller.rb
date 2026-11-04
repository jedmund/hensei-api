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
    # Each subclass declares its type with +collection_item+ and overrides the
    # hooks in the "Per-type hooks" section for what differs between types.
    class CollectionItemsController < ApiController
      Config = Data.define(
        :type, :catalog, :blueprint, :catalog_blueprint, :catalog_view, :import_service,
        :permitted, :owned_includes, :unowned_includes, :proficiency_column
      )

      class_attribute :item_config, instance_writer: false

      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_item_for_read, only: :show
      before_action :restrict_access, except: %i[index show]
      before_action :set_item_for_write, only: %i[update destroy]

      # @param type [Symbol] :character, :weapon or :summon
      # @param catalog [Class] the catalog model (Character, Weapon, Summon)
      # @param blueprint [Class] the collection item blueprint
      # @param catalog_blueprint [Class] the blueprint for unowned catalog rows
      # @param catalog_view [Symbol] the catalog blueprint view
      # @param import_service [Class] the game-data import service
      # @param permitted [Array] attributes a user may set on an item
      # @param owned_includes [Array, Hash] preloads for owned items
      # @param unowned_includes [Array, Hash] preloads for unowned catalog rows
      # @param proficiency_column [Symbol, nil] catalog column the unowned
      #   proficiency sort uses; nil when the type has no proficiency
      def self.collection_item(type, proficiency_column: nil, **)
        self.item_config = Config.new(type:, proficiency_column:, **)
      end

      def index
        params[:unowned].present? ? render_unowned_index : render_owned_index
      end

      def show
        render json: item_config.blueprint.render(@collection_item, view: :full)
      end

      def create
        @collection_item = current_user_items.build(item_params)

        if @collection_item.save
          render json: item_config.blueprint.render(@collection_item, view: :full), status: :created
        else
          render_create_error(@collection_item)
        end
      end

      def update
        assign_item_attributes(@collection_item, item_params)

        if @collection_item.save
          render json: item_config.blueprint.render(@collection_item, view: :full)
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
      # reported in meta.errors and answered with 207.
      def batch
        created = []
        skipped = []
        errors = []

        ActiveRecord::Base.transaction do
          batch_items.each_with_index do |attrs, index|
            if (reason = batch_skip_reason(attrs))
              skipped << { index:, foreign_key => attrs[foreign_key], reason: }
              next
            end

            item = current_user_items.build(attrs)
            if item.save
              created << item
            else
              errors << { index:, foreign_key => attrs[foreign_key], error: item.errors.full_messages.join(', ') }
            end
          end
        end

        render json: item_config.blueprint.render(
          created,
          root: plural_root,
          meta: batch_meta(created:, skipped:, errors:)
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

        result = item_config.import_service.new(current_user, options[:data], **import_options(options)).import

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

        render json: { updates: item_config.import_service.new(current_user, game_data).preview_updates }
      end

      private

      # --- Per-type hooks ---

      # Type-specific filters on the owned index, after element, rarity, series and search.
      def filter_owned_by_type(scope)
        scope
      end

      # Type-specific filters on the unowned index, after element and rarity.
      def filter_unowned_by_type(scope)
        scope
      end

      def assign_item_attributes(item, attrs)
        item.assign_attributes(attrs)
      end

      def render_create_error(item)
        render_validation_error_response(item)
      end

      # A reason string skips the item in a batch instead of creating it.
      def batch_skip_reason(_attrs)
        nil
      end

      def batch_meta(created:, errors:, **)
        { created: created.size, errors: errors }
      end

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

      def render_owned_index
        items = filter_owned(target_user_items.includes(item_config.owned_includes))
                .sorted_by(params[:sort], viewer_language)
                .paginate(page: params[:page], per_page: collection_page_size)

        render json: item_config.blueprint.render(items, root: plural_root, meta: pagination_meta(items))
      end

      def render_unowned_index
        owned_ids = target_user_items.select(foreign_key).distinct
        catalog = item_config.catalog.where.not(id: owned_ids).includes(item_config.unowned_includes)
        catalog = sort_unowned(filter_unowned(catalog)).paginate(page: params[:page], per_page: collection_page_size)

        render json: item_config.catalog_blueprint.render(
          catalog,
          view: item_config.catalog_view,
          root: plural_root,
          meta: pagination_meta(catalog)
        )
      end

      # array_param splits comma-separated values, so each filter matches any of them
      def filter_owned(scope)
        scope = scope.by_element(array_param(:element)) if params[:element]
        scope = scope.by_rarity(array_param(:rarity)) if params[:rarity]
        scope = scope.by_series(array_param(:series)) if params[:series]
        scope = scope.by_name(params[:search]) if params[:search].present?
        filter_owned_by_type(scope)
      end

      def filter_unowned(scope)
        scope = scope.where(element: array_param(:element)) if params[:element]
        scope = scope.where(rarity: array_param(:rarity)) if params[:rarity]
        scope = filter_unowned_by_type(scope)
        return scope if params[:search].blank?

        table = item_config.catalog.table_name
        query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
        scope.where("#{table}.name_en ILIKE :q OR #{table}.name_jp ILIKE :q", q: query)
      end

      def sort_unowned(scope)
        scope.order(*unowned_orders.fetch(params[:sort], [{ latest_date: :desc, id: :asc }]))
      end

      def unowned_orders
        name = "#{item_config.catalog.table_name}.#{viewer_language == 'ja' ? 'name_jp' : 'name_en'}"
        orders = {
          'name_asc' => [Arel.sql("#{name} ASC NULLS LAST")],
          'name_desc' => [Arel.sql("#{name} DESC NULLS LAST")],
          'element_asc' => [{ element: :asc }],
          'element_desc' => [{ element: :desc }],
          'release_date_desc' => [Arel.sql('latest_date DESC NULLS LAST'), { id: :asc }],
          'release_date_asc' => [Arel.sql('latest_date ASC NULLS LAST'), { id: :asc }]
        }
        return orders unless (column = item_config.proficiency_column)

        orders.merge('proficiency_asc' => [{ column => :asc }], 'proficiency_desc' => [{ column => :desc }])
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
        @collection_item = find_item(target_user_items)
      end

      def set_item_for_write
        @collection_item = find_item(current_user_items)
      end

      def find_item(scope)
        scope.find(params.expect(:id))
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new(item_config.type.to_s, params[:id])
      end

      def target_user_items
        @target_user.public_send(association)
      end

      def current_user_items
        current_user.public_send(association)
      end

      # --- Params ---

      def item_params
        params.expect(param_key => item_config.permitted)
      end

      def batch_items
        params.permit(association => item_config.permitted)[association] || []
      end

      def array_param(key)
        params[key]&.to_s&.split(',')
      end

      def viewer_language
        current_user&.language || 'en'
      end

      def render_missing_data
        render json: { error: 'No data provided' }, status: :bad_request
      end

      def association
        :"collection_#{item_config.type}s"
      end

      def param_key
        :"collection_#{item_config.type}"
      end

      def foreign_key
        :"#{item_config.type}_id"
      end

      def plural_root
        :"#{item_config.type}s"
      end
    end
  end
end
