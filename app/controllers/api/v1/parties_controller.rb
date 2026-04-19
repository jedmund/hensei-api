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

      before_action :set_from_slug, except: %w[create destroy update index favorites grid_update unlink_collection sync_all migrate preview_migrate]
      before_action :set, only: %w[update destroy grid_update]
      before_action :authorize_party!, only: %w[update destroy grid_update]

      # Primary CRUD Actions

      # Creates a new party with optional user association
      # @return [void]
      # Creates a new party.
      def create
        party = Party.new(party_params)
        party.user = current_user if current_user

        # Validate collection source user if provided
        if party_params[:collection_source_user_id].present?
          source_user = User.find_by(id: party_params[:collection_source_user_id])
          if source_user.nil?
            return render_not_found_response('user')
          end
          unless source_user == current_user || source_user.collection_viewable_by?(current_user)
            return render_forbidden_response('Collection is not accessible')
          end
        end

        if party_params && party_params[:raid_id].present? && (raid = Raid.find_by(id: party_params[:raid_id]))
          party.extra = raid.group.extra
        end
        party.last_updated = Time.current
        if party.save
          party.schedule_preview_generation if party.ready_for_preview?
          render json: PartyBlueprint.render(party, view: :created, root: :party), status: :created
        else
          render_validation_error_response(party)
        end
      end

      # Shows a specific party.
      # Uses viewable_by? to check visibility including crew sharing.
      # Also allows access via edit_key for anonymous parties.
      def show
        unless @party.viewable_by?(current_user, admin_mode: admin_mode) || !not_owner?
          return render_unauthorized_response
        end

        if @party
          options = { view: :full, root: :party, current_user: current_user }

          if current_user
            options[:viewer_collection] = fetch_collection_for(@party, current_user)
          end

          if @party.collection_source_user_id.present?
            source_user = @party.collection_source_user
            if source_user && source_user != current_user && source_user.collection_viewable_by?(current_user)
              options[:source_collection] = fetch_collection_for(@party, source_user)
            end
          end

          render json: PartyBlueprint.render(@party, **options)
        else
          render_not_found_response('party')
        end
      end

      # Updates an existing party.
      def update
        @party.attributes = party_params.except(:skill1_id, :skill2_id, :skill3_id)
        if party_params && party_params[:raid_id] && (raid = Raid.find_by(id: party_params[:raid_id]))
          @party.extra = raid.group.extra
        end
        @party.last_updated = Time.current
        if @party.save
          render json: PartyBlueprint.render(@party, view: :full, root: :party)
        else
          render_validation_error_response(@party)
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

      # Migrates anonymous parties to the authenticated user's account.
      def migrate
        raise Api::V1::UnauthorizedError unless current_user

        entries = resolve_edit_key_entries
        if entries.nil?
          return render json: { error: 'Too many parties (max 100)' }, status: :unprocessable_entity
        end

        results = []
        migrated_count = 0

        ActiveRecord::Base.transaction do
          entries.each do |entry|
            shortcode = entry[:shortcode]
            party = Party.find_by(shortcode: shortcode) || Party.find_by(id: shortcode)

            if party.nil?
              results << { shortcode: shortcode, status: 'not_found' }
            elsif party.user_id.present?
              results << { shortcode: shortcode, status: 'already_claimed' }
            elsif !valid_edit_key?(entry[:edit_key].to_s.strip.force_encoding('UTF-8'),
                                   party.edit_key.to_s.strip.force_encoding('UTF-8'))
              results << { shortcode: shortcode, status: 'invalid_key' }
            else
              party.update!(user_id: current_user.id, edit_key: nil)
              migrated_count += 1
              results << { shortcode: shortcode, status: 'migrated' }
            end
          end

          # Clean up deposited edit keys for migrated or already-claimed parties
          claimed_shortcodes = results.select { |r| r[:status].in?(%w[migrated already_claimed]) }.map { |r| r[:shortcode] }
          current_user.user_edit_keys.where(shortcode: claimed_shortcodes).delete_all if claimed_shortcodes.any?
        end

        render json: { results: results, migrated_count: migrated_count }, status: :ok
      end

      # Returns a preview of what migrate would do, without modifying any data.
      def preview_migrate
        raise Api::V1::UnauthorizedError unless current_user

        entries = resolve_edit_key_entries
        if entries.nil?
          return render json: { error: 'Too many parties (max 100)' }, status: :unprocessable_entity
        end

        identifiers = entries.map { |e| e[:shortcode] }.uniq
        uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
        uuid_ids = identifiers.select { |i| i.match?(uuid_pattern) }
        non_uuid_ids = identifiers.reject { |i| i.match?(uuid_pattern) }

        query = Party.includes(
          { raid: :group }, :job,
          { characters: { character: :character_series_records } },
          { weapons: { weapon: [:weapon_series, :weapon_series_variant] } },
          { summons: { summon: :summon_series } }
        )
        conditions = []
        binds = []
        if non_uuid_ids.any?
          conditions << 'shortcode IN (?)'
          binds << non_uuid_ids
        end
        if uuid_ids.any?
          conditions << 'shortcode IN (?)'
          binds << uuid_ids
          conditions << 'id IN (?)'
          binds << uuid_ids
        end
        parties = conditions.any? ? query.where(conditions.join(' OR '), *binds) : Party.none

        # Build lookup by both id and shortcode so either format resolves
        party_lookup = {}
        parties.each do |p|
          party_lookup[p.shortcode] = p
          party_lookup[p.id] = p
        end

        # Deduplicate: skip entries that resolve to an already-seen party
        seen_party_ids = Set.new
        results = []

        entries.each do |entry|
          party = party_lookup[entry[:shortcode]]
          next if party && seen_party_ids.include?(party.id)

          seen_party_ids.add(party.id) if party

          result = if party.nil?
                     { party: nil, status: 'not_found' }
                   elsif party.user_id.present?
                     { party: PartyBlueprint.render_as_hash(party, view: :preview), status: 'already_claimed' }
                   elsif !valid_edit_key?(entry[:edit_key].to_s.strip.force_encoding('UTF-8'),
                                          party.edit_key.to_s.strip.force_encoding('UTF-8'))
                     { party: nil, status: 'invalid_key' }
                   else
                     { party: PartyBlueprint.render_as_hash(party, view: :preview), status: 'ready' }
                   end

          results << result
        end

        render json: { parties: results }, status: :ok
      end

      # Extended Party Actions

      # Creates a remixed copy of an existing party.
      def remix
        new_party = @party.amoeba_dup
        new_party.attributes = { user: current_user, name: remixed_name(@party.name), source_party: @party,
                                 remix: true }
        new_party.local_id = party_params[:local_id] if party_params
        new_party.last_updated = Time.current
        new_party._source_party_for_remap = @party
        if new_party.save
          new_party.schedule_preview_generation
          render json: PartyBlueprint.render(new_party, view: :remixed, root: :party), status: :created
        else
          render_validation_error_response(new_party)
        end
      end

      # Batch updates grid items (weapons, characters, summons) atomically.
      def grid_update
        operations = grid_update_params[:operations]
        options = grid_update_params[:options] || {}

        # Validate all operations first
        validation_errors = validate_grid_operations(operations)
        if validation_errors.any?
          return render_unprocessable_entity_response(
            Api::V1::GranblueError.new("Validation failed: #{validation_errors.join(', ')}")
          )
        end

        changes = []

        ActiveRecord::Base.transaction do
          operations.each do |operation|
            change = apply_grid_operation(operation)
            changes << change if change
          end

          # Compact character positions if needed
          compact_party_character_positions if options[:maintain_character_sequence]
        end

        @party.mark_updated!

        render json: {
          party: PartyBlueprint.render_as_hash(@party.reload, view: :full),
          operations_applied: changes.count,
          changes: changes
        }, status: :ok
      rescue StandardError => e
        render_unprocessable_entity_response(
          Api::V1::GranblueError.new("Grid update failed: #{e.message}")
        )
      end

      # Syncs all linked grid items from their collection sources.
      #
      # POST /parties/:id/sync_all
      def sync_all
        @party = Party.find_by(id: params[:id])
        return render_not_found_response('party') unless @party
        authorize_party!
        return if performed?

        synced = { characters: 0, weapons: 0, summons: 0, artifacts: 0 }

        ActiveRecord::Base.transaction do
          @party.characters.where.not(collection_character_id: nil).each do |gc|
            gc.sync_from_collection!
            synced[:characters] += 1
          end

          @party.weapons.where.not(collection_weapon_id: nil).each do |gw|
            gw.sync_from_collection!
            synced[:weapons] += 1
          end

          @party.summons.where.not(collection_summon_id: nil).each do |gs|
            gs.sync_from_collection!
            synced[:summons] += 1
          end

          GridArtifact.joins(:grid_character)
                      .where(grid_characters: { party_id: @party.id })
                      .where.not(collection_artifact_id: nil)
                      .each do |ga|
            ga.sync_from_collection!
            synced[:artifacts] += 1
          end
        end

        render json: {
          party: PartyBlueprint.render_as_hash(@party.reload, view: :full),
          synced: synced
        }, status: :ok
      end

      # Unlinks all collection items from a party's grid items.
      # Keeps the grid items but removes collection references and clears the collection source.
      #
      # POST /parties/:id/unlink_collection
      def unlink_collection
        @party = Party.find_by(id: params[:id])
        return render_not_found_response('party') unless @party
        return render_unauthorized_response unless @party.user_id == current_user&.id

        ActiveRecord::Base.transaction do
          @party.characters.where.not(collection_character_id: nil)
                .update_all(collection_character_id: nil)
          @party.weapons.where.not(collection_weapon_id: nil)
                .update_all(collection_weapon_id: nil, orphaned: false)
          @party.summons.where.not(collection_summon_id: nil)
                .update_all(collection_summon_id: nil, orphaned: false)
          @party.update!(collection_source_user_id: nil)
        end

        render json: {
          party: PartyBlueprint.render_as_hash(@party.reload, view: :full, current_user: current_user)
        }, status: :ok
      end

      # Lists parties based on query parameters.
      def index
        query = build_filtered_query(build_preview_base_query)
        @parties = query.paginate(page: params[:page], per_page: page_size)

        render json: Api::V1::PartyBlueprint.render(
          @parties,
          view: :list,
          root: :results,
          meta: pagination_meta(@parties)
        )
      end

      # GET /api/v1/parties/favorites
      def favorites
        raise Api::V1::UnauthorizedError unless current_user

        base_query = build_preview_base_query
                     .joins(:favorites)
                     .where(favorites: { user_id: current_user.id })
                     .distinct
        query = build_filtered_query(base_query)
        @parties = query.paginate(page: params[:page], per_page: page_size)

        render json: Api::V1::PartyBlueprint.render(
          @parties,
          view: :list,
          root: :results,
          meta: pagination_meta(@parties)
        )
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
        render json: { state: party.preview_state, generated_at: party.preview_generated_at,
                       ready_for_preview: party.ready_for_preview? }
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

      # Resolves edit key entries from params or the current user's deposited keys.
      # Returns nil if there are too many entries (> 100).
      def resolve_edit_key_entries
        entries = if params[:parties].present?
                    params.require(:parties).map { |p| p.permit(:shortcode, :edit_key) }
                  else
                    current_user.user_edit_keys.map { |uek| { shortcode: uek.shortcode, edit_key: uek.edit_key } }
                  end

        return nil if entries.size > 100

        entries
      end

      # Loads the party by its shortcode.
      def set_from_slug
        @party = Party.includes(
          :user, :job, { raid: :group },
          { characters: [
            { character: [:character_series_records, :style_swap_variants] },
            :awakening, :grid_artifact, :collection_character, :role,
            { substitutions: :substitute_grid }
          ] },
          { weapons: {
            weapon: [:awakenings, :weapon_series, :weapon_series_variant, :weapon_skills, :recruited_character, :base_weapon, :forge_chain_weapons],
            collection_weapon: { collection_weapon_bullets: {} },
            awakening: {},
            weapon_key1: {},
            weapon_key2: {},
            weapon_key3: {},
            ax_modifier1: {},
            ax_modifier2: {},
            befoulment_modifier: {},
            grid_weapon_bullets: :bullet,
            role: {},
            substitutions: :substitute_grid
          } },
          { summons: [{ summon: :summon_series }, :collection_summon, :role, { substitutions: :substitute_grid }] },
          :guidebook1, :guidebook2, :guidebook3,
          { source_party: [{ characters: :character }, { weapons: :weapon }, { summons: :summon }] },
          { remixes: [{ characters: :character }, { weapons: :weapon }, { summons: :summon }] },
          :skill0, :skill1, :skill2, :skill3, :accessory,
          { party_shares: :shareable }
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
          :collection_source_user_id, :full_auto, :auto_guard, :auto_summon, :charge_attack, :solo, :clear_time, :button_count,
          :turn_count, :chain_count, :summon_count, :video_url, :guidebook1_id, :guidebook2_id, :guidebook3_id,
          characters_attributes: [:id, :party_id, :character_id, :position, :uncap_level,
                                  :transcendence_step, :perpetuity, :awakening_id, :awakening_level,
                                  { ring1: %i[modifier strength], ring2: %i[modifier strength], ring3: %i[modifier strength], ring4: %i[modifier strength],
                                    earring: %i[modifier strength] }],
          summons_attributes: %i[id party_id summon_id position main friend quick_summon uncap_level transcendence_step],
          weapons_attributes: %i[id party_id weapon_id position mainhand uncap_level transcendence_step element weapon_key1_id weapon_key2_id weapon_key3_id ax_modifier1_id ax_modifier2_id ax_strength1 ax_strength2 befoulment_modifier_id befoulment_strength exorcism_level awakening_id awakening_level]
        )
      end

      # Permits parameters for grid update operation.
      def grid_update_params
        params.permit(
          operations: %i[type entity id source_id target_id position container],
          options: %i[maintain_character_sequence validate_before_execute]
        )
      end

      # Validates grid operations before executing.
      def validate_grid_operations(operations)
        errors = []

        operations.each_with_index do |op, index|
          case op[:type]
          when 'move'
            errors << "Operation #{index}: missing id" unless op[:id].present?
            errors << "Operation #{index}: missing position" unless op[:position].present?
          when 'swap'
            errors << "Operation #{index}: missing source_id" unless op[:source_id].present?
            errors << "Operation #{index}: missing target_id" unless op[:target_id].present?
          when 'remove'
            errors << "Operation #{index}: missing id" unless op[:id].present?
          else
            errors << "Operation #{index}: unknown operation type #{op[:type]}"
          end

          unless %w[weapon character summon].include?(op[:entity])
            errors << "Operation #{index}: invalid entity type #{op[:entity]}"
          end
        end

        errors
      end

      # Applies a single grid operation.
      def apply_grid_operation(operation)
        case operation[:type]
        when 'move'
          apply_move_operation(operation)
        when 'swap'
          apply_swap_operation(operation)
        when 'remove'
          apply_remove_operation(operation)
        end
      end

      # Applies a move operation.
      def apply_move_operation(operation)
        model_class = grid_model_for_entity(operation[:entity])
        item = model_class.find_by(id: operation[:id], party_id: @party.id)

        raise ActiveRecord::RecordNotFound, "#{operation[:entity]} #{operation[:id]} not found" unless item

        old_position = item.position
        item.update!(position: operation[:position])

        {
          entity: operation[:entity],
          id: operation[:id],
          action: 'moved',
          from: old_position,
          to: operation[:position]
        }
      end

      # Applies a swap operation.
      def apply_swap_operation(operation)
        model_class = grid_model_for_entity(operation[:entity])
        source = model_class.find_by(id: operation[:source_id], party_id: @party.id)
        target = model_class.find_by(id: operation[:target_id], party_id: @party.id)

        return nil unless source && target

        source_pos = source.position
        target_pos = target.position

        # Use a temporary position to avoid conflicts
        source.update!(position: -999)
        target.update!(position: source_pos)
        source.update!(position: target_pos)

        {
          entity: operation[:entity],
          id: operation[:source_id],
          action: 'swapped',
          with: operation[:target_id]
        }
      end

      # Applies a remove operation.
      def apply_remove_operation(operation)
        model_class = grid_model_for_entity(operation[:entity])
        item = model_class.find_by(id: operation[:id], party_id: @party.id)

        return nil unless item

        item.destroy

        {
          entity: operation[:entity],
          id: operation[:id],
          action: 'removed'
        }
      end

      # Returns the model class for a given entity type.
      def grid_model_for_entity(entity)
        case entity
        when 'weapon'
          GridWeapon
        when 'character'
          GridCharacter
        when 'summon'
          GridSummon
        end
      end

      # Fetches collection items for a user that match the party's grid items.
      # Uses the already-eager-loaded grid associations to extract granblue_ids,
      # then batch-queries the user's collection with WHERE IN.
      def fetch_collection_for(party, user)
        char_gids = party.characters.filter_map { |gc| gc.character&.granblue_id }.uniq
        weap_gids = party.weapons.filter_map { |gw| gw.weapon&.granblue_id }.uniq
        summ_gids = party.summons.filter_map { |gs| gs.summon&.granblue_id }.uniq

        {
          characters: char_gids.any? ? user.collection_characters.joins(:character)
            .includes({ character: :character_series_records }, :awakening)
            .where(characters: { granblue_id: char_gids }) : [],
          weapons: weap_gids.any? ? user.collection_weapons.joins(:weapon)
            .includes({ weapon: [:weapon_series, :weapon_series_variant] }, :awakening, :weapon_key1, :weapon_key2, :weapon_key3, :weapon_key4,
                      :ax_modifier1, :ax_modifier2, :befoulment_modifier, { collection_weapon_bullets: :bullet })
            .where(weapons: { granblue_id: weap_gids }) : [],
          summons: summ_gids.any? ? user.collection_summons.joins(:summon)
            .includes(summon: :summon_series)
            .where(summons: { granblue_id: summ_gids }) : []
        }
      end

      # Compacts character positions to maintain sequential filling.
      def compact_party_character_positions
        main_characters = @party.characters.where(position: 0..4).order(:position)

        main_characters.each_with_index do |char, index|
          char.update!(position: index) if char.position != index
        end
      end
    end
  end
end
