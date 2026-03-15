# frozen_string_literal: true

module Api
  module V1
    class EmailVerificationsController < Api::V1::ApiController
      skip_before_action :current_user, only: [:update]
      before_action :doorkeeper_authorize!, only: [:create]

      # POST /email_verifications - resend verification email (authenticated)
      def create
        user = current_user
        return render json: { message: 'Email already verified.' }, status: :ok if user.email_verified?

        if user.verification_token_cooldown?
          return render json: { error: 'Please wait before requesting another email.' }, status: :too_many_requests
        end

        raw_token = user.generate_verification_token!
        SendEmailVerificationJob.perform_later(user.id, raw_token)
        render json: { message: 'Verification email sent.' }, status: :ok
      end

      # PUT /email_verifications - verify the token (unauthenticated)
      def update
        user = User.find_by(email: params[:email]&.downcase)

        unless user&.verification_token_valid?(params[:token])
          return render json: { error: 'Invalid or expired verification token.' }, status: :bad_request
        end

        user.verify_email!
        render json: { message: 'Email verified successfully.' }, status: :ok
      end
    end
  end
end
