# frozen_string_literal: true

module Api
  module V1
    # Controller for managing party-related operations in the API
    # @api public
    class PartiesController < Api::V1::ApiController
      before_action :set_from_slug,
                    except: %w[create destroy update index favorites]
      before_action :set, only: %w[update destroy]
      before_action :authorize, only: %w[update destroy]

      # == Constants

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

      # == Primary CRUD Actions

      # Creates a new party with optional user association
      # @return [void]
      def create
        # Build the party with the provided parameters and assign the user
        party = Party.new(party_params)
        party.user = current_user if current_user

        # If a raid_id is given, look it up and assign the extra flag from its group.
        if party_params && party_params[:raid_id].present?
          if (raid = Raid.find_by(id: party_params[:raid_id]))
            party.extra = raid.group.extra
          end
        end

        # Save and render the party, triggering preview generation if the party is ready
        if party.save
          party.schedule_preview_generation if party.ready_for_preview?
          render json: PartyBlueprint.render(party, view: :created, root: :party),
                 status: :created
        else
          render_validation_error_response(party)
        end
      end

      # Shows a specific party if the user has permission to view it
      # @return [void]
      def show
        # If a party is private, check that the user is the owner or an admin
        if (@party.private? && !current_user) || (@party.private? && not_owner && !admin_mode)
          return render_unauthorized_response
        end

        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party

        render_not_found_response('project')
      end

      # Updates an existing party's attributes
      # @return [void]
      def update
        @party.attributes = party_params.except(:skill1_id, :skill2_id, :skill3_id)

        if party_params && party_params[:raid_id]
          raid = Raid.find_by(id: party_params[:raid_id])
          @party.extra = raid.group.extra
        end

        # TODO: Validate accessory with job

        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party.save

        render_validation_error_response(@party)
      end

      # Deletes a party if the user has permission
      # @return [void]
      def destroy
        render json: PartyBlueprint.render(@party, view: :destroyed, root: :checkin) if @party.destroy
      end

      # == Extended Party Actions

      # Creates a copy of an existing party with attribution
      # @return [void]
      def remix
        new_party = @party.amoeba_dup
        new_party.attributes = {
          user: current_user,
          name: remixed_name(@party.name),
          source_party: @party,
          remix: true
        }

        new_party.local_id = party_params[:local_id] unless party_params.nil?

        if new_party.save
          # Remixed parties should have content, so generate preview
          new_party.schedule_preview_generation
          render json: PartyBlueprint.render(new_party, view: :created, root: :party),
                 status: :created
        else
          render_validation_error_response(new_party)
        end
      end

      # Lists parties based on various filter criteria
      # @return [void]
      def index
        query = Party.includes(
          { raid: :group },
          :job,
          :user,
          :skill0,
          :skill1,
          :skill2,
          :skill3,
          :guidebook1,
          :guidebook2,
          :guidebook3,
          { characters: :character },
          { weapons: :weapon },
          { summons: :summon }
        ).order(visibility: :asc, created_at: :desc)

        query = apply_filters(query)
        query = apply_privacy_settings(query)
        query = apply_includes(query, params[:includes]) if params[:includes].present?
        query = apply_excludes(query, params[:excludes]) if params[:excludes].present?

        @parties = query.paginate(
          page: params[:page],
          per_page: COLLECTION_PER_PAGE
        )

        render json: PartyBlueprint.render(@parties,
                                           view: :preview,
                                           root: :results,
                                           meta: {
                                             count: @parties.total_entries,
                                             total_pages: @parties.total_pages,
                                             per_page: COLLECTION_PER_PAGE
                                           },
                                           current_user: current_user)
      end

      # Lists parties favorited by the current user
      # @return [void]
      def favorites
        raise Api::V1::UnauthorizedError unless current_user

        # Start with base query including relationships and filters
        query = Party.includes(
          { raid: :group },
          :job,
          :user,
          :skill0,
          :skill1,
          :skill2,
          :skill3,
          :guidebook1,
          :guidebook2,
          :guidebook3,
          { characters: :character },
          { weapons: :weapon },
          { summons: :summon }
        ).joins(:favorites)
                     .where(favorites: { user_id: current_user.id }) # Ensure only favorited parties
                     .order(created_at: :desc) # Show newest first
                     .distinct # Avoid duplicates

        # Apply improved filtering logic
        query = apply_filters(query)
        query = apply_privacy_settings(query)
        query = apply_includes(query, params[:includes]) if params[:includes].present?
        query = apply_excludes(query, params[:excludes]) if params[:excludes].present?

        # Paginate results
        @parties = query.paginate(
          page: params[:page],
          per_page: COLLECTION_PER_PAGE
        )

        # Mark all as favorited for the current user
        @parties.each { |party| party.favorited = true }

        render json: PartyBlueprint.render(
          parties,
          view: :preview,
          root: :results,
          meta: {
            count: parties.total_entries,
            total_pages: parties.total_pages,
            per_page: COLLECTION_PER_PAGE
          }
        )
      end

      # == Preview Management

      # Serves the party's preview image
      # @return [void]
      def preview
        coordinator = PreviewService::Coordinator.new(@party)

        if coordinator.generation_in_progress?
          response.headers['Retry-After'] = '2'
          default_path = Rails.root.join('public', 'default-previews', "#{@party.element || 'default'}.png")
          send_file default_path,
                    type: 'image/png',
                    disposition: 'inline'
          return
        end

        # Try to get the preview or send default
        begin
          if Rails.env.production?
            # Stream S3 content instead of redirecting
            s3_object = coordinator.get_s3_object
            send_data s3_object.body.read,
                      filename: "#{@party.shortcode}.png",
                      type: 'image/png',
                      disposition: 'inline'
          else
            # In development, serve from local filesystem
            send_file coordinator.local_preview_path,
                      type: 'image/png',
                      disposition: 'inline'
          end
        rescue Aws::S3::Errors::NoSuchKey
          # Schedule generation if needed
          coordinator.schedule_generation unless coordinator.generation_in_progress?

          # Return default preview while generating
          send_file Rails.root.join('public', 'default-previews', "#{@party.element || 'default'}.png"),
                    type: 'image/png',
                    disposition: 'inline'
        end
      end

      # Returns the current status of a party's preview
      # @return [void]
      def preview_status
        party = Party.find_by!(shortcode: params[:id])
        render json: {
          state: party.preview_state,
          generated_at: party.preview_generated_at,
          ready_for_preview: party.ready_for_preview?
        }
      end

      # Forces regeneration of a party's preview image
      # @return [void]
      def regenerate_preview
        party = Party.find_by!(shortcode: params[:id])

        # Ensure only party owner can force regeneration
        unless current_user && party.user_id == current_user.id
          return render_unauthorized_response
        end

        preview_service = PreviewService::Coordinator.new(party)
        if preview_service.force_regenerate
          render json: { status: 'Preview regeneration started' }
        else
          render json: { error: 'Preview regeneration failed' },
                 status: :unprocessable_entity
        end
      end

      private

      # == Authorization Helpers

      # Checks if the current user is authorized to modify the party
      # @return [void]
      def authorize
        return unless not_owner && !admin_mode

        render_unauthorized_response
      end

      # Determines if the current user is not the owner of the party
      # @return [Boolean]
      def not_owner
        if @party.user
          # party has a user and current_user does not match
          return true if current_user != @party.user

          # party has a user, there's no current_user, but edit_key is provided
          return true if current_user.nil? && edit_key
        else
          # party has no user, there's no current_user and there's no edit_key provided
          return true if current_user.nil? && edit_key.nil?

          # party has no user, there's no current_user, and the party's edit_key doesn't match the provided edit_key
          return true if current_user.nil? && @party.edit_key != edit_key
        end

        false
      end

      # == Preview Generation

      # Schedules a background job to generate the party preview
      # @return [void]
      def schedule_preview_generation
        GeneratePartyPreviewJob.perform_later(id)
      end

      # == Query Building Helpers

      def apply_filters(query)
        conditions = build_filters

        # Use the compound indexes effectively
        query = query.where(conditions)
                     .where(name_quality) if params[:name_quality].present?

        # Use the counters index
        query = query.where(
          weapons_count: build_count(params[:weapons_count], DEFAULT_MIN_WEAPONS)..MAX_WEAPONS,
          characters_count: build_count(params[:characters_count], DEFAULT_MIN_CHARACTERS)..MAX_CHARACTERS,
          summons_count: build_count(params[:summons_count], DEFAULT_MIN_SUMMONS)..MAX_SUMMONS
        )

        query
      end

      def apply_privacy_settings(query)
        return query if admin_mode

        if params[:favorites].present?
          query.where('visibility < 3')
        else
          query.where(visibility: 1)
        end
      end

      # Builds filter conditions from request parameters
      # @return [Hash] conditions for the query
      def build_filters
        {
          element: params[:element].present? ? params[:element].to_i : nil,
          raid_id: params[:raid],
          created_at: build_date_range,
          full_auto: build_option(params[:full_auto]),
          auto_guard: build_option(params[:auto_guard]),
          charge_attack: build_option(params[:charge_attack]),
          characters_count: build_count(params[:characters_count], DEFAULT_MIN_CHARACTERS)..MAX_CHARACTERS,
          summons_count: build_count(params[:summons_count], DEFAULT_MIN_SUMMONS)..MAX_SUMMONS,
          weapons_count: build_count(params[:weapons_count], DEFAULT_MIN_WEAPONS)..MAX_WEAPONS
        }.compact
      end

      def build_date_range
        return nil unless params[:recency].present?

        start_time = DateTime.current - params[:recency].to_i.seconds
        start_time.beginning_of_day..DateTime.current
      end

      # Paginates the given query of parties and marks favorites for the current user
      #
      # @param query [ActiveRecord::Relation] The base query containing parties
      # @param page [Integer, nil] The page number for pagination (defaults to `params[:page]`)
      # @param per_page [Integer] The number of records per page (defaults to `COLLECTION_PER_PAGE`)
      # @return [ActiveRecord::Relation] The paginated and processed list of parties
      #
      # This method orders parties by creation date in descending order, applies pagination,
      # and marks each party as favorited if the current user has favorited it.
      def paginate_parties(query, page: nil, per_page: COLLECTION_PER_PAGE)
        query.order(created_at: :desc)
             .paginate(page: page || params[:page], per_page: per_page)
             .tap do |parties|
          if current_user
            parties.each { |party| party.favorited = party.is_favorited(current_user) }
          end
        end
      end

      # == Parameter Processing Helpers

      # Converts start time parameter for filtering
      # @param recency [String, nil] time period in seconds
      # @return [DateTime, nil] calculated start time
      def build_start_time(recency)
        return unless recency.present?

        (DateTime.current - recency.to_i.seconds).to_datetime.beginning_of_day
      end

      # Builds count parameter with default fallback
      # @param value [String, nil] count value
      # @param default [Integer] default value
      # @return [Integer] processed count
      def build_count(value, default)
        value.blank? ? default : value.to_i
      end

      # Processes maximum clear time parameter
      # @param value [String, nil] clear time value in seconds
      # @return [Integer] processed maximum clear time
      def build_max_clear_time(value)
        value.blank? ? DEFAULT_MAX_CLEAR_TIME : value.to_i
      end

      # Processes element parameter
      # @param element [String, nil] element identifier
      # @return [Integer, nil] processed element value
      def build_element(element)
        element.to_i unless element.blank?
      end

      # Processes boolean option parameters
      # @param value [String, nil] option value
      # @return [Integer, nil] processed option value
      def build_option(value)
        value.to_i unless value.blank? || value.to_i == -1
      end

      # == Query Building Helpers

      # Constructs the main query for party filtering
      # @param conditions [Hash] filter conditions
      # @param favorites [Boolean] whether to include favorites
      # @return [ActiveRecord::Relation] constructed query
      def build_query(conditions, favorites: false)
        query = Party.distinct
        # joins vs includes? -> reduces n+1s
                     .preload(
                       weapons: { object: %i[name_en name_jp granblue_id element] },
                       summons: { object: %i[name_en name_jp granblue_id element] },
                       characters: { object: %i[name_en name_jp granblue_id element] }
                     )
                     .group('parties.id')
                     .where(conditions)
                     .where(privacy(favorites: favorites))
                     .where(name_quality)
                     .where(user_quality)
                     .where(original)

        query = query.includes(:favorites) if favorites

        query
      end

      # Applies the include conditions to query
      # @param query [ActiveRecord::Relation] base query
      # @param includes [String] comma-separated list of IDs to include
      # @return [ActiveRecord::Relation] modified query
      def apply_includes(query, includes)
        return query unless includes.present?

        includes.split(',').each do |id|
          grid_table, object_table = grid_table_and_object_table(id)
          next unless grid_table && object_table

          # Build a subquery that joins the grid table to the object table.
          condition = <<-SQL.squish
      EXISTS (
        SELECT 1
        FROM #{grid_table}
        JOIN #{object_table} ON #{grid_table}.#{object_table.singularize}_id = #{object_table}.id
        WHERE #{object_table}.granblue_id = ?
          AND #{grid_table}.party_id = parties.id
      )
          SQL

          query = query.where(condition, id)
        end

        query
      end

      # Applies the exclude conditions to query
      # @param query [ActiveRecord::Relation] base query
      # @return [ActiveRecord::Relation] modified query
      def apply_excludes(query, excludes)
        return query unless excludes.present?

        excludes.split(',').each do |id|
          grid_table, object_table = grid_table_and_object_table(id)
          next unless grid_table && object_table

          condition = <<-SQL.squish
      NOT EXISTS (
        SELECT 1
        FROM #{grid_table}
        JOIN #{object_table} ON #{grid_table}.#{object_table.singularize}_id = #{object_table}.id
        WHERE #{object_table}.granblue_id = ?
          AND #{grid_table}.party_id = parties.id
      )
          SQL

          query = query.where(condition, id)
        end

        query
      end

      # == Query Filtering Helpers

      # Generates subquery for excluded characters
      # @return [ActiveRecord::Relation, nil] exclusion query
      def excluded_characters
        return unless params[:excludes]

        excluded = params[:excludes].split(',').filter { |id| id[0] == '3' }
        GridCharacter.includes(:object)
                     .where(characters: { granblue_id: excluded })
                     .where('grid_characters.party_id = parties.id')
      end

      # Generates subquery for excluded summons
      # @return [ActiveRecord::Relation, nil] exclusion query
      def excluded_summons
        return unless params[:excludes]

        excluded = params[:excludes].split(',').filter { |id| id[0] == '2' }
        GridSummon.includes(:object)
                  .where(summons: { granblue_id: excluded })
                  .where('grid_summons.party_id = parties.id')
      end

      # Generates subquery for excluded weapons
      # @return [ActiveRecord::Relation, nil] exclusion query
      def excluded_weapons
        return unless params[:excludes]

        excluded = params[:excludes].split(',').filter { |id| id[0] == '1' }
        GridWeapon.includes(:object)
                  .where(weapons: { granblue_id: excluded })
                  .where('grid_weapons.party_id = parties.id')
      end

      # == Query Processing

      # Fetches and processes parties query with pagination
      # @param query [ActiveRecord::Relation] base query
      # @return [ActiveRecord::Relation] processed and paginated parties
      def fetch_parties(query)
        query.order(created_at: :desc)
             .paginate(page: params[:page], per_page: COLLECTION_PER_PAGE)
             .each { |party| party.favorited = current_user ? party.is_favorited(current_user) : false }
      end

      # Calculates total count for pagination
      # @param query [ActiveRecord::Relation] current query
      # @return [Integer] total count
      def calculate_count(query)
        # query.count.values.sum
        query.count
      end

      # Calculates total pages for pagination
      # @param count [Integer] total record count
      # @return [Integer] total pages
      def calculate_total_pages(count)
        # count.to_f / COLLECTION_PER_PAGE > 1 ? (count.to_f / COLLECTION_PER_PAGE).ceil : 1
        (count.to_f / COLLECTION_PER_PAGE).ceil
      end

      # == Include/Exclude Processing

      # Generates SQL for including specific items
      # @param id [String] item identifier
      # @return [String] SQL condition
      def includes(id)
        "(\"#{id_to_table(id)}\".\"granblue_id\" = '#{id}')"
      end

      # Generates SQL for excluding specific items
      # @param id [String] item identifier
      # @return [String] SQL condition
      def excludes(id)
        "(\"#{id_to_table(id)}\".\"granblue_id\" != '#{id}')"
      end

      # == Filter Condition Helpers

      # Generates user quality condition
      # @return [String, nil] SQL condition for user quality
      def user_quality
        return if params[:user_quality].blank? || params[:user_quality] == 'false'

        'user_id IS NOT NULL'
      end

      # Generates name quality condition
      # @return [String, nil] SQL condition for name quality
      def name_quality
        return if params[:name_quality].blank? || params[:name_quality] == 'false'

        low_quality = [
          'Untitled',
          'Remix of Untitled',
          'Remix of Remix of Untitled',
          'Remix of Remix of Remix of Untitled',
          'Remix of Remix of Remix of Remix of Untitled',
          'Remix of Remix of Remix of Remix of Remix of Untitled',
          '無題',
          '無題のリミックス',
          '無題のリミックスのリミックス',
          '無題のリミックスのリミックスのリミックス',
          '無題のリミックスのリミックスのリミックスのリミックス',
          '無題のリミックスのリミックスのリミックスのリミックスのリミックス'
        ]
        joined_names = low_quality.map { |name| "'#{name}'" }.join(',')
        "name NOT IN (#{joined_names})"
      end

      # Generates original party condition
      # @return [String, nil] SQL condition for original parties
      def original
        return if params['original'].blank? || params['original'] == 'false'

        'source_party_id IS NULL'
      end

      # == Filter Condition Helpers

      # Generates privacy condition based on favorites
      # @param favorites [Boolean] whether viewing favorites
      # @return [String, nil] SQL condition
      def privacy(favorites: false)
        return if admin_mode

        if favorites
          'visibility < 3'
        else
          'visibility = 1'
        end
      end

      # == Utility Methods

      # Maps ID prefixes to table names
      # @param id [String] item identifier
      # @return [Array(String, String)] corresponding table name
      def grid_table_and_object_table(id)
        case id[0]
        when '3'
          %w[grid_characters characters]
        when '2'
          %w[grid_summons summons]
        when '1'
          %w[grid_weapons weapons]
        else
          [nil, nil]
        end
      end

      # Generates name for remixed party
      # @param name [String] original party name
      # @return [String] generated remix name
      def remixed_name(name)
        blanked_name = {
          en: name.blank? ? 'Untitled team' : name,
          ja: name.blank? ? '無名の編成' : name
        }

        if current_user
          case current_user.language
          when 'en'
            "Remix of #{blanked_name[:en]}"
          when 'ja'
            "#{blanked_name[:ja]}のリミックス"
          end
        else
          "Remix of #{blanked_name[:en]}"
        end
      end

      # == Party Loading

      # Loads party by shortcode for routes using :id
      # @return [void]
      def set_from_slug
        @party = Party.where('shortcode = ?', params[:id]).first
        if @party
          @party.favorited = current_user && @party ? @party.is_favorited(current_user) : false
        else
          render_not_found_response('party')
        end
      end

      # Loads party by ID for update/destroy actions
      # @return [void]
      def set
        @party = Party.where('id = ?', params[:id]).first
      end

      # == Parameter Sanitization

      # Sanitizes and permits party parameters
      # @return [Hash, nil] permitted parameters
      def party_params
        return unless params[:party].present?

        params.require(:party).permit(
          :user_id,
          :local_id,
          :edit_key,
          :extra,
          :name,
          :description,
          :raid_id,
          :job_id,
          :visibility,
          :accessory_id,
          :skill0_id,
          :skill1_id,
          :skill2_id,
          :skill3_id,
          :full_auto,
          :auto_guard,
          :auto_summon,
          :charge_attack,
          :clear_time,
          :button_count,
          :turn_count,
          :chain_count,
          :guidebook1_id,
          :guidebook2_id,
          :guidebook3_id,
          characters_attributes: [:id, :party_id, :character_id, :position,
                                  :uncap_level, :transcendence_step, :perpetuity,
                                  :awakening_id, :awakening_level,
                                  { ring1: %i[modifier strength], ring2: %i[modifier strength],
                                    ring3: %i[modifier strength], ring4: %i[modifier strength],
                                    earring: %i[modifier strength] }],
          summons_attributes: %i[id party_id summon_id position main friend
                                 quick_summon uncap_level transcendence_step],
          weapons_attributes: %i[id party_id weapon_id
                                 position mainhand uncap_level transcendence_step element
                                 weapon_key1_id weapon_key2_id weapon_key3_id
                                 ax_modifier1 ax_modifier2 ax_strength1 ax_strength2
                                 awakening_id awakening_level]
        )
      end
    end
  end
end
