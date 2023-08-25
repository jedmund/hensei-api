# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::ApiController
      class ForbiddenError < StandardError; end

      before_action :set, except: %w[create check_email check_username]
      before_action :set_by_id, only: %w[info update]

      MAX_CHARACTERS = 5
      MAX_SUMMONS = 8
      MAX_WEAPONS = 13

      DEFAULT_MIN_CHARACTERS = 0
      DEFAULT_MIN_SUMMONS = 0
      DEFAULT_MIN_WEAPONS = 0

      DEFAULT_MAX_CLEAR_TIME = 5400

      def create
        user = User.new(user_params)

        if user.save!
          token = Doorkeeper::AccessToken.create!(
            application_id: nil,
            resource_owner_id: user.id,
            expires_in: 30.days,
            scopes: 'public'
          ).token

          return render json: UserBlueprint.render({
                                                     id: user.id,
                                                     username: user.username,
                                                     token: token
                                                   },
                                                   view: :token),
                        status: :created
        end

        render_validation_error_response(@user)
      end

      # TODO: Allow admins to update other users

      def update
        render json: UserBlueprint.render(@user, view: :minimal) if @user.update(user_params)
      end

      def info
        render json: UserBlueprint.render(@user, view: :minimal)
      end

      def show
        if @user.nil?
          render_not_found_response('user')
        else
          conditions = build_conditions
          conditions[:user_id] = @user.id

          parties = Party
                    .where(conditions)
                    .where(name_quality)
                    .where(user_quality)
                    .where(original)
                    .where(privacy)
                    .order(created_at: :desc)
                    .paginate(page: request.params[:page], per_page: COLLECTION_PER_PAGE)
                    .each do |party|
            party.favorited = current_user ? party.is_favorited(current_user) : false
          end

          count = Party.where(conditions).count

          render json: UserBlueprint.render(@user,
                                            view: :profile,
                                            root: 'profile',
                                            parties: parties,
                                            meta: {
                                              count: count,
                                              total_pages: count.to_f / COLLECTION_PER_PAGE > 1 ? (count.to_f / COLLECTION_PER_PAGE).ceil : 1,
                                              per_page: COLLECTION_PER_PAGE
                                            })
        end
      end

      def check_email
        render json: EmptyBlueprint.render_as_json(nil, email: params[:email], availability: true)
      end

      def check_username
        render json: EmptyBlueprint.render_as_json(nil, username: params[:username], availability: true)
      end

      def destroy; end

      private

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

        'source_party_id IS NULL'
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
        @user = User.find_by('lower(username) = ?', params[:id].downcase)
      end

      def set_by_id
        @user = User.find_by('id = ?', params[:id])
      end

      def user_params
        params.require(:user).permit(
          :username, :email, :password, :password_confirmation,
          :granblue_id, :picture, :element, :language, :gender, :private, :theme
        )
      end
    end
  end
end
