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

        {}.tap do |hash|
          hash[:element] = params['element'] unless params['element'].blank?
          hash[:raid] = params['raid'] unless params['raid'].blank?
          hash[:created_at] = start_time..DateTime.current unless params['recency'].blank?
        end
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
