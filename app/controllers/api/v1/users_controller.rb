# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::ApiController
      class ForbiddenError < StandardError; end

      include IssuesTokens

      # update looks the user up by id (set_by_id); the rest look up by username
      # (set). update must be excluded from set so its id isn't treated as a
      # username (which now 404s on miss).
      before_action :set, except: %w[create check_email check_username me search deposit_edit_keys update]
      before_action :doorkeeper_authorize!, only: %w[me search deposit_edit_keys update]
      before_action :set_by_id, only: %w[update]

      # Signups arrive via the web app's server, so the per-IP limit is generous;
      # the availability checks are called from browsers directly.
      limit_requests 'signup', to: 60, within: 1.minute, only: :create
      limit_requests 'availability', to: 30, within: 1.minute, only: %i[check_email check_username]
      limit_requests 'social-signup', to: 20, within: 1.minute, only: :create, if: -> { params[:signup_ticket].present? }

      USER_FIELDS = %i[username email password password_confirmation display_name
                       description granblue_id picture element language gender private
                       theme show_gamertag wiki_profile youtube collection_privacy
                       import_weapons default_import_visibility simple_portraits
                       default_rep_view timezone support_summons_public].freeze

      # Flags that only ever turn on, each stamping its timestamp the first
      # time it's sent as true. Only the flag is accepted, never the timestamp.
      ONE_WAY_FLAGS = {
        password_prompt_dismissed: :password_prompt_dismissed_at,
        wiki_export_guidelines_accepted: :wiki_export_guidelines_accepted_at
      }.freeze

      def show
        if @user.nil?
          render_not_found_response('user')
        else
          base_query = Party.includes(
            { raid: :group },
            :job,
            :solomonis_expedition,
            :user,
            :skill0,
            :skill1,
            :skill2,
            :skill3,
            :guidebook1,
            :guidebook2,
            :guidebook3,
            { characters: [{ character: :character_series_records }, :grid_artifact, :awakening] },
            { weapons: [{ weapon: %i[weapon_series weapon_series_variant], collection_weapon: {} }, :awakening] },
            { summons: [{ summon: :summon_series }, :collection_summon] }
          )
          # Restrict to parties belonging to the profile owner
          base_query = base_query.where(user_id: @user.id)
          skip_privacy = (current_user&.id == @user.id)
          query = PartyQueryBuilder.new(
            base_query,
            params: params,
            current_user: current_user,
            options: { skip_privacy: skip_privacy, admin_mode: admin_mode }
          ).build
          current_page_size = page_size
          parties = query.paginate(page: params[:page], per_page: current_page_size)
          count = query.count
          render json: UserBlueprint.render(@user,
                                            view: :profile,
                                            root: 'profile',
                                            parties: parties,
                                            meta: { count: count, total_pages: (count.to_f / current_page_size).ceil, per_page: current_page_size },
                                            current_user: current_user)
        end
      end

      def create
        return create_from_signup_ticket if params[:signup_ticket].present?

        user = User.new(user_params)

        unless user.save
          Rails.logger.error "[Registration] Validation failed: #{user.errors.full_messages.join(', ')}"
          return render json: { error: 'Validation failed', messages: user.errors.full_messages },
                        status: :unprocessable_content
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
        render json: { error: 'Registration failed' },
               status: :internal_server_error
      end

      # TODO: Allow admins to update other users

      # Email and password are not updatable here; they change only through
      # registration and the password reset flow.
      def update
        attrs = user_update_params
        flags = attrs.extract!(*ONE_WAY_FLAGS.keys)
        @user.assign_attributes(attrs)
        apply_one_way_flags(flags)
        if @user.save
          render json: UserBlueprint.render(@user, view: :minimal)
        else
          render_validation_error_response(@user)
        end
      end

      def info
        payload = UserBlueprint.render_as_hash(@user, view: :minimal)
        cast_bool = ActiveModel::Type::Boolean.new

        payload[:collection_accessible] = @user.collection_viewable_by?(current_user) if cast_bool.cast(params[:check_collection])

        payload[:support_summons_accessible] = @user.support_summons_viewable_by?(current_user) if cast_bool.cast(params[:check_support_summons])

        render json: payload
      end

      def search
        query = params[:query].to_s.strip
        return render json: { users: [] } if query.length < 2

        escaped = query.downcase.gsub(/[\\%_]/) { |c| "\\#{c}" }
        q = "#{escaped}%"
        users = User
                .where("LOWER(username) LIKE :q ESCAPE '\\' OR LOWER(display_name) LIKE :q ESCAPE '\\'", q: q)
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

      # Looks the email up and reports whether it is already registered. The
      # register form relies on this; the endpoint is rate limited above.
      def check_email
        available = User.where(email: params[:email].to_s).none?
        render json: { available: available }
      end

      def check_username
        username = params[:username].to_s.strip
        normalized = username.downcase
        segments = normalized.split(/[_-]+/)
        candidates = segments + [normalized]

        profane = candidates.any? { |c| ProfanityValidator.word_list(:en, tier: :strict).include?(c) }
        reserved = ProfanityValidator.reserved_list.include?(normalized)

        available = username.length.between?(3, 26) &&
                    username.match?(User::USERNAME_FORMAT) &&
                    !profane &&
                    !reserved &&
                    User.with_username(normalized).none?
        render json: { available: available }
      end

      def deposit_edit_keys
        entries = params.require(:edit_keys).map { |e| e.permit(:shortcode, :edit_key) }

        return render json: { error: 'Too many edit keys (max 100)' }, status: :unprocessable_content if entries.size > 100

        entries.each do |entry|
          current_user.user_edit_keys.find_or_create_by(edit_key: entry[:edit_key]) do |uek|
            uek.shortcode = entry[:shortcode]
          end
        end

        render json: { deposited: entries.size }, status: :ok
      end

      private

      # POST /users with a signup_ticket from POST /auth/:provider: creates a
      # passwordless account linked to the provider and returns the full token
      # body (with a refresh token), like a sign-in.
      def create_from_signup_ticket
        ticket = SocialAuth::Ticket.read(params[:signup_ticket], purpose: :signup)
        return render json: { error: 'invalid_ticket' }, status: :unauthorized unless ticket

        attrs = params.fetch(:user, {})
        attrs = attrs.respond_to?(:permit) ? attrs.permit(:username, :email) : {}
        signup = SocialAuth::Signup.new(ticket, username: attrs[:username], email: attrs[:email])
        unless signup.call
          return render json: { error: 'Validation failed', messages: signup.user.errors.full_messages },
                        status: :unprocessable_content
        end

        send_verification_email(signup.user) unless signup.user.email_verified?
        render_token_response(signup.user, status: :created)
      rescue SocialAuth::Signup::IdentityTaken
        render json: { error: 'invalid_ticket' }, status: :unauthorized
      end

      def send_verification_email(user)
        raw_token = user.generate_verification_token!
        SendEmailVerificationJob.perform_later(user.id, raw_token)
      end

      # See ONE_WAY_FLAGS. Sending false never clears a timestamp.
      def apply_one_way_flags(flags)
        cast = ActiveModel::Type::Boolean.new
        flags.each do |flag, value|
          next unless cast.cast(value)

          column = ONE_WAY_FLAGS.fetch(flag.to_sym)
          @user[column] ||= Time.current
        end
      end

      # Loads the user named in the path. 404s for unknown usernames so bot
      # probes (sitemap.xml, favicon.ico, ...) don't render a nil user through
      # the blueprint and 500.
      def set
        @user = User.includes(active_crew_membership: :crew).with_username(params[:id]).first
        render_not_found_response('user') unless @user
      end

      # Users may only update themselves: accepts 'me' or the caller's own id.
      def set_by_id
        return render_forbidden_response unless params[:id] == 'me' || params[:id] == current_user.id

        @user = User.includes(active_crew_membership: :crew).find(current_user.id)
      end

      def user_params
        params.expect(user: USER_FIELDS)
      end

      # Also takes the ONE_WAY_FLAGS, which update hands to
      # apply_one_way_flags rather than assigning (they aren't columns)
      def user_update_params
        params.expect(user: [*USER_FIELDS, *ONE_WAY_FLAGS.keys])
              .except(:email, :password, :password_confirmation)
      end
    end
  end
end
