# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::ApiController
      class ForbiddenError < StandardError; end

      before_action :set, except: %w[create check_email check_username me search deposit_edit_keys]
      before_action :set_by_id, only: %w[update]
      before_action :doorkeeper_authorize!, only: %w[me search deposit_edit_keys]

      MAX_CHARACTERS = 5
      MAX_SUMMONS = 8
      MAX_WEAPONS = 13

      DEFAULT_MIN_CHARACTERS = 0
      DEFAULT_MIN_SUMMONS = 0
      DEFAULT_MIN_WEAPONS = 0

      DEFAULT_MAX_CLEAR_TIME = 5400

      def create
        user = User.new(user_params)

        unless user.save
          Rails.logger.error "[Registration] Validation failed: #{user.errors.full_messages.join(', ')}"
          return render json: { error: 'Validation failed', messages: user.errors.full_messages },
                        status: :unprocessable_entity
        end

        token = Doorkeeper::AccessToken.create!(
          application_id: nil,
          resource_owner_id: user.id,
          expires_in: 30.days,
          scopes: 'public'
        ).token

        raw_token = user.generate_verification_token!
        SendEmailVerificationJob.perform_later(user.id, raw_token)

        render json: UserBlueprint.render({
                                            id: user.id,
                                            username: user.username,
                                            token: token,
                                            email_verified: false
                                          },
                                          view: :token),
                      status: :created
      rescue StandardError => e
        Rails.logger.error "[Registration] Unexpected error: #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace&.first(10)&.join("\n")
        render json: { error: 'Registration failed', message: e.message },
               status: :internal_server_error
      end

      # TODO: Allow admins to update other users

      def update
        render json: UserBlueprint.render(@user, view: :minimal) if @user.update(user_params)
      end

      def info
        render json: UserBlueprint.render(@user, view: :minimal)
      end

      def search
        query = params[:query].to_s.strip
        return render json: { users: [] } if query.length < 2

        users = User.where('lower(username) LIKE ?', "#{query.downcase}%")
                     .where.not(id: current_user.id)
                     .includes(active_crew_membership: :crew)
                     .limit(10)
        render json: { users: UserBlueprint.render_as_hash(users, view: :minimal) }
      end

      # GET /users/me - returns current user's settings including email
      # This endpoint is ONLY for authenticated users viewing their own settings
      def me
        render json: UserBlueprint.render(current_user, view: :settings)
      end

      def show
        if @user.nil?
          render_not_found_response('user')
        else
          base_query = Party.includes(
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
            { characters: [{ character: :character_series_records }, :grid_artifact, :awakening] },
            { weapons: [{ weapon: [:weapon_series, :weapon_series_variant], collection_weapon: {} }, :awakening] },
            { summons: [:summon, :collection_summon] }
          )
          # Restrict to parties belonging to the profile owner
          base_query = base_query.where(user_id: @user.id)
          skip_privacy = (current_user&.id == @user.id)
          query = PartyQueryBuilder.new(
            base_query,
            params: params,
            current_user: current_user,
            options: { skip_privacy: skip_privacy }
          ).build
          current_page_size = page_size
          parties = query.paginate(page: params[:page], per_page: current_page_size)
          count = query.count
          render json: UserBlueprint.render(@user,
                                            view: :profile,
                                            root: 'profile',
                                            parties: parties,
                                            meta: { count: count, total_pages: (count.to_f / current_page_size).ceil, per_page: current_page_size },
                                            current_user: current_user
          )
        end
      end

      def check_email
        render json: EmptyBlueprint.render_as_json(nil, email: params[:email], availability: true)
      end

      def check_username
        username = params[:username].to_s.strip
        normalized = username.downcase
        segments = normalized.split(/[_\-]+/)
        candidates = segments + [normalized]

        profane = candidates.any? { |c| ProfanityValidator.word_list(:en, tier: :strict).include?(c) }
        reserved = ProfanityValidator.reserved_list.include?(normalized)

        available = username.length.between?(3, 26) &&
                    username.match?(User::USERNAME_FORMAT) &&
                    !profane &&
                    !reserved &&
                    User.where('lower(username) = ?', normalized).none?
        render json: { available: available }
      end

      def deposit_edit_keys
        entries = params.require(:edit_keys).map { |e| e.permit(:shortcode, :edit_key) }

        if entries.size > 100
          return render json: { error: 'Too many edit keys (max 100)' }, status: :unprocessable_entity
        end

        entries.each do |entry|
          current_user.user_edit_keys.find_or_create_by(edit_key: entry[:edit_key]) do |uek|
            uek.shortcode = entry[:shortcode]
          end
        end

        render json: { deposited: entries.size }, status: :ok
      end

      def destroy; end

      private

      def build_profile_query(profile_user)
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
          { characters: [{ character: :character_series_records }, :awakening] },
          { weapons: [{ weapon: [:weapon_series, :weapon_series_variant] }, :awakening] },
          { summons: :summon }
        )
        # Restrict to parties belonging to the profile’s owner.
        query = query.where(user_id: profile_user.id)
        # Then apply the additional filters that we normally use:
        query = query.where(name_quality)
                     .where(user_quality)
                     .where(original)
                     .where(privacy)
        # And if there are any request-supplied filters, includes, or excludes:
        query = apply_filters(query) if params[:filters].present?
        query = apply_includes(query, params[:includes]) if params[:includes].present?
        query = apply_excludes(query, params[:excludes]) if params[:excludes].present?
        query.order(created_at: :desc)
      end

      def build_conditions
        params = request.params

        unless params['recency'].blank?
          start_time = (DateTime.current - params['recency'].to_i.seconds)
                         .to_datetime.beginning_of_day
        end

        min_characters_count = params['characters_count'].blank? ? DEFAULT_MIN_CHARACTERS : params['characters_count'].to_i
        min_summons_count = params['summons_count'].blank? ? DEFAULT_MIN_SUMMONS : params['summons_count'].to_i
        min_weapons_count = params['weapons_count'].blank? ? DEFAULT_MIN_WEAPONS : params['weapons_count'].to_i
        max_clear_time = params['max_clear_time'].blank? ? DEFAULT_MAX_CLEAR_TIME : params['max_clear_time'].to_i

        {}.tap do |hash|
          # Basic filters
          hash[:element] = params['element'].to_i unless params['element'].blank?
          hash[:raid] = params['raid'] unless params['raid'].blank?
          hash[:created_at] = start_time..DateTime.current unless params['recency'].blank?

          # Advanced filters: Team parameters
          unless params['full_auto'].blank? || params['full_auto'].to_i == -1
            hash[:full_auto] =
              params['full_auto'].to_i
          end
          unless params['auto_guard'].blank? || params['auto_guard'].to_i == -1
            hash[:auto_guard] =
              params['auto_guard'].to_i
          end
          unless params['charge_attack'].blank? || params['charge_attack'].to_i == -1
            hash[:charge_attack] =
              params['charge_attack'].to_i
          end

          # Turn count of 0 will not be displayed, so disallow on the frontend or set default to 1
          # How do we do the same for button count since that can reasonably be 1?
          # hash[:turn_count] = params['turn_count'].to_i unless params['turn_count'].blank? || params['turn_count'].to_i <= 0
          # hash[:button_count] = params['button_count'].to_i unless params['button_count'].blank?
          # hash[:clear_time] = 0..max_clear_time

          # Advanced filters: Object counts
          hash[:characters_count] = min_characters_count..MAX_CHARACTERS
          hash[:summons_count] = min_summons_count..MAX_SUMMONS
          hash[:weapons_count] = min_weapons_count..MAX_WEAPONS
        end
      end

      def original
        return if params.key?('original') || params['original'].blank? || params['original'] == '0'

        'remix = false'
      end

      def user_quality
        return if params.key?('user_quality') || params[:user_quality].nil? || params[:user_quality] == '0'

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

        return if params.key?('name_quality') || params[:name_quality].nil? || params[:name_quality] == '0'

        "name NOT IN (#{joined_names})"
      end

      def privacy
        return if admin_mode

        'visibility = 1' if current_user != @user
      end

      # Specify whitelisted properties that can be modified.
      def set
        @user = User.includes(active_crew_membership: :crew).find_by('lower(username) = ?', params[:id].downcase)
      end

      def set_by_id
        if params[:id] == 'me'
          @user = User.includes(active_crew_membership: :crew).find(current_user.id)
        else
          @user = User.includes(active_crew_membership: :crew).find_by('id = ?', params[:id])
        end
      end

      def user_params
        params.require(:user).permit(
          :username, :email, :password, :password_confirmation, :display_name,
          :granblue_id, :picture, :element, :language, :gender, :private, :theme, :show_gamertag,
          :wiki_profile, :youtube, :collection_privacy,
          :import_weapons, :default_import_visibility, :simple_portraits
        )
      end
    end
  end
end
