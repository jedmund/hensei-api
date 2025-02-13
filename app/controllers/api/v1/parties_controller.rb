# frozen_string_literal: true

module Api
  module V1
    # Controller for managing party-related operations in the API
    # @api public
    class PartiesController < Api::V1::ApiController
      include PartyAuthorizationConcern
      include PartyQueryingConcern
      include PartyPreviewConcern

      # Constants used for filtering validations.

      # Maximum number of characters allowed in a party
      MAX_CHARACTERS = 5

      # Maximum number of summons allowed in a party
      MAX_SUMMONS = 8

      # Maximum number of weapons allowed in a party
      MAX_WEAPONS = 13

      # Default minimum number of characters required for filtering
      DEFAULT_MIN_CHARACTERS = 3

      # Default minimum number of summons required for filtering
      DEFAULT_MIN_SUMMONS = 2

      # Default minimum number of weapons required for filtering
      DEFAULT_MIN_WEAPONS = 5

      # Default maximum clear time in seconds
      DEFAULT_MAX_CLEAR_TIME = 5400

      before_action :set_from_slug, except: %w[create destroy update index favorites]
      before_action :set, only: %w[update destroy]
      before_action :authorize_party!, only: %w[update destroy]

      # Primary CRUD Actions

      # Creates a new party with optional user association
      # @return [void]
      # Creates a new party.
      def create
        party = Party.new(party_params)
        party.user = current_user if current_user
        if party_params && party_params[:raid_id].present?
          if (raid = Raid.find_by(id: party_params[:raid_id]))
            party.extra = raid.group.extra
          end
        end
        if party.save
          party.schedule_preview_generation if party.ready_for_preview?
          render json: PartyBlueprint.render(party, view: :created, root: :party), status: :created
        else
          render_validation_error_response(party)
        end
      end

      # Shows a specific party.
      def show
        return render_unauthorized_response if @party.private? && (!current_user || not_owner?)

        if @party
          render json: PartyBlueprint.render(@party, view: :full, root: :party)
        else
          render_not_found_response('project')
        end
      end

      # Updates an existing party.
      def update
        @party.attributes = party_params.except(:skill1_id, :skill2_id, :skill3_id)
        if party_params && party_params[:raid_id]
          if (raid = Raid.find_by(id: party_params[:raid_id]))
            @party.extra = raid.group.extra
          end
        end
        if @party.save
          render json: PartyBlueprint.render(@party, view: :full, root: :party)
        else
          render_validation_error_response(@party)
        end
      end

      # Deletes a party.
      def destroy
        render json: PartyBlueprint.render(@party, view: :destroyed, root: :checkin) if @party.destroy
      end

      # Extended Party Actions

      # Creates a remixed copy of an existing party.
      def remix
        new_party = @party.amoeba_dup
        new_party.attributes = { user: current_user, name: remixed_name(@party.name), source_party: @party, remix: true }
        new_party.local_id = party_params[:local_id] if party_params
        if new_party.save
          new_party.schedule_preview_generation
          render json: PartyBlueprint.render(new_party, view: :remixed, root: :party), status: :created
        else
          render_validation_error_response(new_party)
        end
      end

      # Lists parties based on query parameters.
      def index
        query = build_filtered_query(build_common_base_query)
        @parties = query.paginate(page: params[:page], per_page: COLLECTION_PER_PAGE)
        render_paginated_parties(@parties)
      end

      # GET /api/v1/parties/favorites
      def favorites
        raise Api::V1::UnauthorizedError unless current_user

        base_query = build_common_base_query
                       .joins(:favorites)
                       .where(favorites: { user_id: current_user.id })
                       .distinct
        query = build_filtered_query(base_query)
        @parties = query.paginate(page: params[:page], per_page: COLLECTION_PER_PAGE)
        render_paginated_parties(@parties)
      end

      # Preview Management

      # Serves the party's preview image
      # @return [void]
      # Serves the party's preview image.
      def preview
        party_preview(@party)
      end

      # Returns the current preview status of a party.
      def preview_status
        party = Party.find_by!(shortcode: params[:id])
        render json: { state: party.preview_state, generated_at: party.preview_generated_at, ready_for_preview: party.ready_for_preview? }
      end

      # Forces regeneration of the party preview.
      def regenerate_preview
        party = Party.find_by!(shortcode: params[:id])
        return render_unauthorized_response unless current_user && party.user_id == current_user.id

        preview_service = PreviewService::Coordinator.new(party)
        if preview_service.force_regenerate
          render json: { status: 'Preview regeneration started' }
        else
          render json: { error: 'Preview regeneration failed' }, status: :unprocessable_entity
        end
      end

      private

      # Loads the party by its shortcode.
      def set_from_slug
        @party = Party.includes(
          :user, :job, { raid: :group },
          { characters: %i[character awakening] },
          { weapons: {
            weapon: [:awakenings],
            awakening: {},
            weapon_key1: {},
            weapon_key2: {},
            weapon_key3: {}
          }
          },
          { summons: :summon },
          :guidebook1, :guidebook2, :guidebook3,
          :source_party, :remixes, :skill0, :skill1, :skill2, :skill3, :accessory
        ).find_by(shortcode: params[:id])
        render_not_found_response('party') unless @party
      end

      # Loads the party by its id.
      def set
        @party = Party.where('id = ?', params[:id]).first
      end

      # Sanitizes and permits party parameters.
      def party_params
        return unless params[:party].present?

        params.require(:party).permit(
          :user_id, :local_id, :edit_key, :extra, :name, :description, :raid_id, :job_id, :visibility,
          :accessory_id, :skill0_id, :skill1_id, :skill2_id, :skill3_id,
          :full_auto, :auto_guard, :auto_summon, :charge_attack, :clear_time, :button_count,
          :turn_count, :chain_count, :guidebook1_id, :guidebook2_id, :guidebook3_id,
          characters_attributes: [:id, :party_id, :character_id, :position, :uncap_level,
                                  :transcendence_step, :perpetuity, :awakening_id, :awakening_level,
                                  { ring1: %i[modifier strength], ring2: %i[modifier strength], ring3: %i[modifier strength], ring4: %i[modifier strength],
                                    earring: %i[modifier strength] }],
          summons_attributes: %i[id party_id summon_id position main friend quick_summon uncap_level transcendence_step],
          weapons_attributes: %i[id party_id weapon_id position mainhand uncap_level transcendence_step element weapon_key1_id weapon_key2_id weapon_key3_id ax_modifier1 ax_modifier2 ax_strength1 ax_strength2 awakening_id awakening_level]
        )
      end
    end
  end
end
