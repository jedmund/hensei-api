class Api::V1::UsersController < Api::V1::ApiController
    class ForbiddenError < StandardError; end

    before_action :set, except: ['create', 'check_email', 'check_username']

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

    def show
        @parties = @user.parties
        ap "Hello world"
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

    def show
        if @user
            @parties = @user.parties
        else
            render_not_found_response
        end
    end

    def update
    end

    def destroy
    end

    private

    # Specify whitelisted properties that can be modified.
    def set
        @user = User.where("username = ?", params[:id]).first
    end

    def user_params
        params.require(:user).permit(:username, :email, :password, :password_confirmation, :granblue_id)
    end
end