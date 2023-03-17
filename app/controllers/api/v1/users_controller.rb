# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::V1::ApiController
      class ForbiddenError < StandardError; end

      before_action :set, except: %w[create check_email check_username]
      before_action :set_by_id, only: %w[info update]

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

          conditions = build_conditions(request.params)
          conditions[:user_id] = @user.id

          parties = Party
                      .where(conditions)
                      .where(name_quality)
                      .where(user_quality)
                      .where(original)
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

      def build_conditions(params)
        unless params['recency'].blank?
          start_time = (DateTime.current - params['recency'].to_i.seconds)
                         .to_datetime.beginning_of_day
        end
        min_characters_count = params['min_characters'] ? params['min_characters'] : 3
        min_summons_count = params['min_summons'] ? params['min_summons'] : 2
        min_weapons_count = params['min_weapons'] ? params['min_weapons'] : 5

        max_clear_time = params['max_clear_time'] ? params['max_clear_time'] : 5400

        {}.tap do |hash|
          # Basic filters
          hash[:element] = params['element'] unless params['element'].blank?
          hash[:raid] = params['raid'] unless params['raid'].blank?
          hash[:created_at] = start_time..DateTime.current unless params['recency'].blank?

          # Advanced filters: Team parameters
          hash[:full_auto] = params['full_auto'] unless params['full_auto'].blank?
          hash[:charge_attack] = params['charge_attack'] unless params['charge_attack'].blank?

          hash[:turn_count] = params['max_turns'] unless params['max_turns'].blank?
          hash[:button_count] = params['max_buttons'] unless params['max_buttons'].blank?
          hash[:clear_time] = 0..max_clear_time

          # Advanced filters: Object counts
          hash[:characters_count] = min_characters_count..5
          hash[:summons_count] = min_summons_count..8
          hash[:weapons_count] = min_weapons_count..13
        end
      end

      def original
        "source_party_id IS NULL" unless params['original'].blank? || params['original'] == '0'
      end

      def user_quality
        "user_id IS NOT NULL" unless params[:user_quality].nil? || params[:user_quality] == "0"
      end

      def name_quality
        low_quality = [
          "Untitled",
          "Remix of Untitled",
          "Remix of Remix of Untitled",
          "Remix of Remix of Remix of Untitled",
          "Remix of Remix of Remix of Remix of Untitled",
          "Remix of Remix of Remix of Remix of Remix of Untitled",
          "無題",
          "無題のリミックス",
          "無題のリミックスのリミックス",
          "無題のリミックスのリミックスのリミックス",
          "無題のリミックスのリミックスのリミックスのリミックス",
          "無題のリミックスのリミックスのリミックスのリミックスのリミックス"
        ]

        joined_names = low_quality.map { |name| "'#{name}'" }.join(',')

        "name NOT IN (#{joined_names})" unless params[:name_quality].nil? || params[:name_quality] == "0"
      end

      # Specify whitelisted properties that can be modified.
      def set
        @user = User.where('username = ?', params[:id]).first
      end

      def set_by_id
        @user = User.where('id = ?', params[:id]).first
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
