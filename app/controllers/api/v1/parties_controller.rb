# frozen_string_literal: true

module Api
  module V1
    # Controller for managing party-related operations in the API
    # @api public
    class PartiesController < Api::V1::ApiController
      include CollectionSourceConcern
      include PartyAuthorizationConcern
      include PartyQueryingConcern
      include SubstituteGridPreloading
      include PartyFullLoading

      # Fields of `party[solomonis]` a client may write. ended_at, stats and
      # game_report_id are import-only; ownership comes from the party.
      SOLOMONIS_PARAMS = %i[route_evoker_id pledge_level outcome].freeze

      # Validation error keys on the party's expedition, as the API contract
      # names them (`solomonis.<field>`).
      SOLOMONIS_ERROR_KEYS = {
        'solomonis_expedition' => 'solomonis.route_evoker_id',
        'solomonis_expedition.route_evoker' => 'solomonis.route_evoker_id'
      }.freeze

      # Fields of `party` a client may write. Ownership (user, edit key) is
      # never among them.
      PARTY_FIELDS = %i[
        local_id extra name description raid_id job_id visibility
        accessory_id skill0_id skill1_id skill2_id skill3_id
        collection_source_user_id full_auto auto_guard auto_summon charge_attack solo clear_time button_count
        turn_count chain_count summon_count ultimate_mastery ultimate_mastery_level
        video_url guidebook1_id guidebook2_id guidebook3_id
      ].freeze

      RING_FIELDS = %i[modifier strength].freeze

      # Fields of the nested grid items in `party`.
      CHARACTER_FIELDS = [
        :id, :character_id, :position, :uncap_level, :transcendence_step, :perpetuity, :awakening_id, :awakening_level,
        { ring1: RING_FIELDS, ring2: RING_FIELDS, ring3: RING_FIELDS, ring4: RING_FIELDS, earring: RING_FIELDS }
      ].freeze
      SUMMON_FIELDS = %i[id summon_id position main friend quick_summon uncap_level transcendence_step].freeze
      WEAPON_FIELDS = %i[
        id weapon_id position mainhand uncap_level transcendence_step element
        weapon_key1_id weapon_key2_id weapon_key3_id ax_modifier1_id ax_modifier2_id ax_strength1 ax_strength2
        befoulment_modifier_id befoulment_strength befoulment_permeation exorcism_level awakening_id awakening_level
      ].freeze

      before_action :set_from_slug, except: %w[create destroy update index favorites unlink_collection sync_all]
      before_action :set, only: %w[update destroy sync_all]
      before_action :authorize_party!, only: %w[update destroy sync_all]
      before_action :ensure_party_viewable!, only: %w[show skill_boosts remix]

      # Lists parties based on query parameters.
      def index
        query = build_filtered_query(build_preview_base_query)
        @parties = query.paginate(page: params[:page], per_page: page_size)

        render json: Api::V1::PartyBlueprint.render(
          @parties,
          view: :list,
          root: :results,
          meta: pagination_meta(@parties),
          current_user: current_user
        )
      end

      # Shows a party, with the viewer's matching collection items and those of
      # the party's collection source when the viewer may see them. Private
      # parties 404 unless viewable (ensure_party_viewable!).
      def show
        options = { view: :full, root: :party, current_user: current_user, admin_mode: admin_mode }
        options[:viewer_collection] = PartyCollectionMatches.for(@party, current_user) if current_user

        source_user = @party.collection_source_user
        if source_user && source_user != current_user && source_user.collection_viewable_by?(current_user)
          options[:source_collection] = PartyCollectionMatches.for(@party, source_user)
        end

        render json: PartyBlueprint.render(@party, **options)
      end

      # Creates a party, owned by the current user when signed in.
      def create
        party = Party.new(party_params)
        party.user = current_user if current_user

        # Validate collection source user if provided
        if party_params[:collection_source_user_id].present?
          source_user = User.find_by(id: party_params[:collection_source_user_id])
          return render_not_found_response('user') if source_user.nil?
          return render_forbidden_response('Collection is not accessible') unless collection_visible?(source_user)
        end

        if party_params && party_params[:raid_id].present? && (raid = Raid.find_by(id: party_params[:raid_id]))
          party.extra = raid.group.extra
        end
        assign_solomonis_params(party)
        return if performed?

        party.last_updated = Time.current
        if party.save
          render json: PartyBlueprint.render(load_full_party(party.id), view: :created, root: :party,
                                                                        current_user: current_user,
                                                                        admin_mode: admin_mode),
                 status: :created
        else
          render_party_errors(party)
        end
      end

      # Updates an existing party.
      def update
        # The collection source is set (and validated) on create only.
        @party.attributes = party_params.except(:skill1_id, :skill2_id, :skill3_id, :collection_source_user_id)
        if party_params && party_params[:raid_id] && (raid = Raid.find_by(id: party_params[:raid_id]))
          @party.extra = raid.group.extra
        end
        assign_solomonis_params(@party)
        return if performed?

        @party.last_updated = Time.current
        if @party.save
          render json: PartyBlueprint.render(load_full_party(@party.id), view: :full, root: :party,
                                                                         current_user: current_user,
                                                                         admin_mode: admin_mode)
        else
          render_party_errors(@party)
        end
      end

      # Deletes a party.
      def destroy
        if @party.destroy
          head :no_content
        else
          render_unprocessable_entity_response(
            Api::V1::PartyDeletionFailedError.new(@party.errors.full_messages)
          )
        end
      end

      # GET /api/v1/parties/favorites
      def favorites
        raise Api::V1::UnauthorizedError unless current_user

        # A subquery rather than a join + DISTINCT, which Postgres can't order
        # by an expression such as the Rising rank
        base_query = build_preview_base_query
                     .where(id: Favorite.where(user_id: current_user.id).select(:party_id))
        query = build_filtered_query(base_query)
        @parties = query.paginate(page: params[:page], per_page: page_size)

        render json: Api::V1::PartyBlueprint.render(
          @parties,
          view: :list,
          root: :results,
          meta: pagination_meta(@parties),
          current_user: current_user
        )
      end

      # The in-game "Weapon Skill Boosts" panel for this party's grid, computed by
      # GridDamage::Calculator for the battle state in the params (GridDamage::PanelState).
      def skill_boosts
        state = GridDamage::PanelState.from_params(params, @party)
        render json: GridDamage::PanelPresenter.present(@party, state: state).merge(state: state)
      end

      # Creates a remixed copy of an existing party.
      def remix
        new_party = @party.amoeba_dup
        new_party.attributes = { user: current_user, name: remixed_name(@party.name), source_party: @party,
                                 remix: true }
        new_party.local_id = party_params[:local_id] if party_params
        new_party.last_updated = Time.current
        new_party._source_party_for_remap = @party
        new_party.keep_only_collection_links_of!(current_user)
        if new_party.save
          render json: PartyBlueprint.render(load_full_party(new_party.id), view: :remixed, root: :party,
                                                                            current_user: current_user,
                                                                            admin_mode: admin_mode), status: :created
        else
          render_validation_error_response(new_party)
        end
      end

      # Syncs all linked grid items from their collection sources.
      #
      # POST /parties/:id/sync_all
      def sync_all
        result = PartyCollectionSync.new(@party).sync_all! { |item| collection_accessible?(item) }

        render json: {
          party: PartyBlueprint.render_as_hash(load_full_party(@party.id), view: :full,
                                                                           current_user: current_user,
                                                                           admin_mode: admin_mode),
          synced: result.synced,
          skipped: result.skipped
        }, status: :ok
      end

      # Unlinks all collection items from a party's grid items.
      # Keeps the grid items but removes collection references and clears the collection source.
      #
      # POST /parties/:id/unlink_collection
      def unlink_collection
        @party = Party.find_by(id: params[:id])
        return render_not_found_response('party') unless @party
        return render_unauthorized_response unless current_user && @party.user_id == current_user.id

        PartyCollectionSync.new(@party).unlink!

        render json: {
          party: PartyBlueprint.render_as_hash(load_full_party(@party.id), view: :full,
                                                                           current_user: current_user,
                                                                           admin_mode: admin_mode)
        }, status: :ok
      end

      private

      # Private parties 404 for anyone who can't view them, so their existence
      # isn't revealed. Anonymous parties are also viewable with their edit key.
      def ensure_party_viewable!
        return if performed?
        return if can_view_party?

        render_not_found_response('party')
      end

      def can_view_party?
        return true if @party.viewable_by?(current_user, admin_mode: admin_mode)
        return false unless @party.user_id.nil?

        @party.edit_key_matches?(edit_key)
      end

      # Loads the party by its shortcode.
      def set_from_slug
        @party = Party.includes(full_party_preloads).find_by(shortcode: params[:id])

        return render_not_found_response('party') unless @party

        # Most parties have zero substitutes; a single EXISTS lookup is far cheaper
        # than the three collection-ownership queries `preload_substitute_grids!` runs.
        preload_substitute_grids!(@party.characters + @party.weapons + @party.summons) if @party.substitutions?
      end

      # Loads the party by its id.
      def set
        @party = Party.find_by(id: params[:id].to_s[UUID_FORMAT])
      end

      # Sanitizes and permits party parameters. Not `params.expect`: a `party`
      # holding only `solomonis` permits to nothing, which expect would refuse.
      def party_params
        return if params[:party].blank?

        params.fetch(:party).permit(*PARTY_FIELDS, full_auto_skills: %w[0 1 2 3],
                                                   characters_attributes: CHARACTER_FIELDS,
                                                   summons_attributes: SUMMON_FIELDS,
                                                   weapons_attributes: WEAPON_FIELDS)
      end

      # Whether the current user may see a user's collection.
      def collection_visible?(user)
        user == current_user || user.collection_viewable_by?(current_user)
      end

      def solomonis_params
        raw = params[:party].is_a?(ActionController::Parameters) ? params[:party][:solomonis] : nil
        return nil unless raw.is_a?(ActionController::Parameters)

        raw.permit(*SOLOMONIS_PARAMS)
      end

      # Applies `party[solomonis]` to the party's expedition (building one when
      # the party has none).
      def assign_solomonis_params(party)
        attrs = solomonis_params&.to_h
        return if attrs.nil?

        party.solomonis_expedition_attributes = attrs
      end

      # Renders a party's validation errors in the usual format, with the
      # expedition's keys renamed to the contract's `solomonis.*` names. A
      # party moved into a Solomonis zone without a route Evoker fails on
      # `solomonis.route_evoker_id` (D12).
      def render_party_errors(party)
        errors = Hash.new { |hash, key| hash[key] = [] }
        party.errors.each do |error|
          attribute = error.attribute.to_s
          if attribute == 'solomonis_expedition'
            errors['solomonis.route_evoker_id'] << 'is required to enter an Evoking Solomonis zone'
          else
            key = SOLOMONIS_ERROR_KEYS[attribute] || attribute.sub(/\Asolomonis_expedition\./, 'solomonis.')
            errors[key] << error.message
          end
        end
        render_solomonis_errors(errors)
      end

      def render_solomonis_errors(errors)
        render json: ErrorBlueprint.render_as_json(nil, errors: errors.to_h), status: :unprocessable_content
      end
    end
  end
end
