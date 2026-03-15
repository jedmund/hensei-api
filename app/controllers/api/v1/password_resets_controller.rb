# frozen_string_literal: true

module Api
  module V1
    class PasswordResetsController < Api::V1::ApiController
      skip_before_action :current_user

      def create
        user = User.find_by(email: params[:email]&.downcase)

        if user && !user.reset_token_cooldown?
          raw_token = user.generate_reset_token!
          SendPasswordResetEmailJob.perform_later(user.id, raw_token)
        end

        render json: { message: 'If that email is registered, a reset link has been sent.' }, status: :ok
      end

      def update
        user = User.find_by(email: params[:email]&.downcase)

        unless user&.reset_token_valid?(params[:token])
          return render json: { error: 'Invalid or expired reset token.' }, status: :bad_request
        end

        user.password = params[:password]
        user.password_confirmation = params[:password_confirmation]

        if user.save
          user.clear_reset_token!
          Doorkeeper::AccessToken.where(resource_owner_id: user.id).destroy_all
          render json: { message: 'Password has been reset.' }, status: :ok
        else
          render json: ErrorBlueprint.render_as_json(nil, errors: user.errors),
                 status: :unprocessable_entity
        end
      end
    end
  end
end
