# frozen_string_literal: true

module Api
  module V1
    class PartiesController < Api::V1::ApiController
      before_action :set_from_slug,
                    except: %w[create destroy update index favorites]
      before_action :set, only: %w[update destroy]
      before_action :authorize, only: %w[update destroy]

      MAX_CHARACTERS = 5
      MAX_SUMMONS = 8
      MAX_WEAPONS = 13

      DEFAULT_MIN_CHARACTERS = 3
      DEFAULT_MIN_SUMMONS = 2
      DEFAULT_MIN_WEAPONS = 5

      DEFAULT_MAX_CLEAR_TIME = 5400

      def create
        party = Party.new
        party.user = current_user if current_user
        party.attributes = party_params if party_params

        if party_params && party_params[:raid_id]
          raid = Raid.find_by(id: party_params[:raid_id])
          party.extra = raid.group.extra
        end

        if party.save!
          return render json: PartyBlueprint.render(party, view: :created, root: :party),
                        status: :created
        end

        render_validation_error_response(@party)
      end

      def show
        # If a party is private, check that the user is the owner or an admin
        if (@party.private? && !current_user) || (@party.private? && not_owner && !admin_mode)
          return render_unauthorized_response
        end

        return render json: PartyBlueprint.render(@party, view: :full, root: :party) if @party

        render_not_found_response('project')
      end

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

      def destroy
        return render json: PartyBlueprint.render(@party, view: :destroyed, root: :checkin) if @party.destroy
      end

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
          render json: PartyBlueprint.render(new_party, view: :created, root: :party),
                 status: :created
        else
          render_validation_error_response(new_party)
        end
      end

      def index
        conditions = build_filters

        query = build_query(conditions)
        query = apply_includes(query, params[:includes]) if params[:includes].present?
        query = apply_excludes(query, params[:excludes]) if params[:excludes].present?

        @parties = fetch_parties(query)
        count = calculate_count(query)
        total_pages = calculate_total_pages(count)

        render_party_json(@parties, count, total_pages)
      end

      def favorites
        raise Api::V1::UnauthorizedError unless current_user

        conditions = build_filters
        conditions[:favorites] = { user_id: current_user.id }

        query = build_query(conditions, favorites: true)
        query = apply_includes(query, params[:includes]) if params[:includes].present?
        query = apply_excludes(query, params[:excludes]) if params[:excludes].present?

        @parties = fetch_parties(query)
        count = calculate_count(query)
        total_pages = calculate_total_pages(count)

        render_party_json(@parties, count, total_pages)
      end

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

      def authorize
        return unless not_owner && !admin_mode

        render_unauthorized_response
      end

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

      def build_filters
        params = request.params

        start_time = build_start_time(params['recency'])

        min_characters_count = build_count(params['characters_count'], DEFAULT_MIN_CHARACTERS)
        min_summons_count = build_count(params['summons_count'], DEFAULT_MIN_SUMMONS)
        min_weapons_count = build_count(params['weapons_count'], DEFAULT_MIN_WEAPONS)
        max_clear_time = build_max_clear_time(params['max_clear_time'])

        {
          element: build_element(params['element']),
          raid: params['raid'],
          created_at: params['recency'].present? ? start_time..DateTime.current : nil,
          full_auto: build_option(params['full_auto']),
          auto_guard: build_option(params['auto_guard']),
          charge_attack: build_option(params['charge_attack']),
          characters_count: min_characters_count..MAX_CHARACTERS,
          summons_count: min_summons_count..MAX_SUMMONS,
          weapons_count: min_weapons_count..MAX_WEAPONS
        }.delete_if { |_k, v| v.nil? }
      end

      def build_start_time(recency)
        return unless recency.present?

        (DateTime.current - recency.to_i.seconds).to_datetime.beginning_of_day
      end

      def build_count(value, default)
        value.blank? ? default : value.to_i
      end

      def build_max_clear_time(value)
        value.blank? ? DEFAULT_MAX_CLEAR_TIME : value.to_i
      end

      def build_element(element)
        element.to_i unless element.blank?
      end

      def build_option(value)
        value.to_i unless value.blank? || value.to_i == -1
      end

      def build_query(conditions, favorites: false)
        query = Party.distinct
                     .joins(weapons: [:object], summons: [:object], characters: [:object])
                     .group('parties.id')
                     .where(conditions)
                     .where(privacy(favorites: favorites))
                     .where(name_quality)
                     .where(user_quality)
                     .where(original)

        query = query.joins(:favorites) if favorites

        query
      end

      def includes(id)
        "(\"#{id_to_table(id)}\".\"granblue_id\" = '#{id}')"
      end

      def excludes(id)
        "(\"#{id_to_table(id)}\".\"granblue_id\" != '#{id}')"
      end

      def apply_includes(query, includes)
        included = includes.split(',')
        includes_condition = included.map { |id| includes(id) }.join(' AND ')
        query.where(includes_condition)
      end

      def apply_excludes(query, _excludes)
        characters_subquery = excluded_characters.select(1).arel
        summons_subquery = excluded_summons.select(1).arel
        weapons_subquery = excluded_weapons.select(1).arel

        query.where(characters_subquery.exists.not)
             .where(weapons_subquery.exists.not)
             .where(summons_subquery.exists.not)
      end

      def excluded_characters
        return unless params[:excludes]

        excluded = params[:excludes].split(',').filter { |id| id[0] == '3' }
        GridCharacter.joins(:object)
                     .where(characters: { granblue_id: excluded })
                     .where('grid_characters.party_id = parties.id')
      end

      def excluded_summons
        return unless params[:excludes]

        excluded = params[:excludes].split(',').filter { |id| id[0] == '2' }
        GridSummon.joins(:object)
                  .where(summons: { granblue_id: excluded })
                  .where('grid_summons.party_id = parties.id')
      end

      def excluded_weapons
        return unless params[:excludes]

        excluded = params[:excludes].split(',').filter { |id| id[0] == '1' }
        GridWeapon.joins(:object)
                  .where(weapons: { granblue_id: excluded })
                  .where('grid_weapons.party_id = parties.id')
      end

      def fetch_parties(query)
        query.order(created_at: :desc)
             .paginate(page: request.params[:page], per_page: COLLECTION_PER_PAGE)
             .each { |party| party.favorited = current_user ? party.is_favorited(current_user) : false }
      end

      def calculate_count(query)
        query.count.values.sum
      end

      def calculate_total_pages(count)
        count.to_f / COLLECTION_PER_PAGE > 1 ? (count.to_f / COLLECTION_PER_PAGE).ceil : 1
      end

      def render_party_json(parties, count, total_pages)
        render json: PartyBlueprint.render(parties,
                                           view: :collection,
                                           root: :results,
                                           meta: {
                                             count: count,
                                             total_pages: total_pages,
                                             per_page: COLLECTION_PER_PAGE
                                           })
      end

      def privacy(favorites: false)
        return if admin_mode

        if favorites
          'visibility < 3'
        else
          'visibility = 1'
        end
      end

      def user_quality
        return if request.params[:user_quality].blank? || request.params[:user_quality] == 'false'

        'user_id IS NOT NULL'
      end

      def name_quality
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

        return if request.params[:name_quality].blank? || request.params[:name_quality] == 'false'

        "name NOT IN (#{joined_names})"
      end

      def original
        return if request.params['original'].blank? || request.params['original'] == 'false'

        'source_party_id IS NULL'
      end

      def id_to_table(id)
        case id[0]
        when '3'
          table = 'characters'
        when '2'
          table = 'summons'
        when '1'
          table = 'weapons'
        end

        table
      end

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

      def set_from_slug
        @party = Party.where('shortcode = ?', params[:id]).first
        if @party
          @party.favorited = current_user && @party ? @party.is_favorited(current_user) : false
        else
          render_not_found_response('party')
        end
      end

      def set
        @party = Party.where('id = ?', params[:id]).first
      end

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
