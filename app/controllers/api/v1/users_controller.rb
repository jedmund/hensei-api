class Api::V1::UsersController < Api::V1::ApiController
    def create
        @user = User.new(user_params)
        render :create, status: :created if @user.save!
    end

    def email_available
        @available = User.where("email = ?", params[:email]).count == 0
        render :email_available
    end

    def show
    end

    def update
    end

    def destroy
    end

    private

    # Specify whitelisted properties that can be modified.
    def user_params
        params.require(:user).permit(:username, :email, :password, :password_confirmation, :granblue_id)
    end
end