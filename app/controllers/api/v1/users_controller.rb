class Api::V1::UsersController < Api::V1::ApiController
    class ForbiddenError < StandardError; end

    before_action :set, except: ['create', 'check_email', 'check_username']
    before_action :set_by_id, only: ['info', 'update']

    def create
        @user = User.new(user_params)

        token = Doorkeeper::AccessToken.create!(
            application_id: nil,
            resource_owner_id: @user.id,
            expires_in: 30.days,
            scopes: 'public'
        ).token

        if @user.save!
            @presenter = {
                user_id: @user.id,
                username: @user.username,
                token: token
            }

            render :create, status: :created
        end
    end


    def update
        render :info, status: :ok if @user.update(user_params)
    end

    def info
        render :info, status: :ok
    end

    def show
        if @user
            @per_page = 15

            now = DateTime.current
            start_time = (now - params['recency'].to_i.seconds).to_datetime.beginning_of_day unless request.params['recency'].blank?

            conditions = {}
            conditions[:element] = request.params['element'] unless request.params['element'].blank?
            conditions[:raid] = request.params['raid'] unless request.params['raid'].blank?
            conditions[:created_at] = start_time..now unless request.params['recency'].blank? 
            conditions[:user_id] = @user.id

            @parties = Party
                .where(conditions)
                .order(created_at: :desc)
                .paginate(page: request.params[:page], per_page: @per_page)
                .each { |party|
                    party.favorited = (current_user) ? party.is_favorited(current_user) : false
                }
            @count = Party.where(conditions).count
        else
            render_not_found_response
        end
    end

    def check_email
        if params[:email].present?
            @available = User.where("email = ?", params[:email]).count == 0
        else
            @available = false
        end

        render :available
    end

    def check_username
        if params[:username].present?
            @available = User.where("username = ?", params[:username]).count == 0
        else
            @available = false
        end

        render :available
    end

    def destroy
    end

    private

    # Specify whitelisted properties that can be modified.
    def set
        @user = User.where("username = ?", params[:id]).first
    end

    def set_by_id
        @user = User.where("id = ?", params[:id]).first
    end

    def user_params
        params.require(:user).permit(
            :username, :email, :password, :password_confirmation, 
            :granblue_id, :picture, :element, :language, :gender, :private
        )
    end
end