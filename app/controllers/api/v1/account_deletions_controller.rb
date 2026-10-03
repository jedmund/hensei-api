# frozen_string_literal: true

module Api
  module V1
    # Self-serve account deletion (/users/me/deletion). Requesting it schedules
    # the account for deletion after User::DELETION_GRACE_PERIOD and signs the
    # user out everywhere; logging back in and cancelling keeps the account.
    class AccountDeletionsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!

      # The password check makes this a password oracle for a stolen session.
      limit_requests 'account-deletion', to: 5, within: 15.minutes, only: :create,
                                         by: -> { "user:#{current_user&.id || client_ip}" }

      # Accounts created with a login provider must set a password first (the
      # reset email does that), so every deletion is confirmed the same way.
      def create
        return render json: { error: 'password_required' }, status: :unprocessable_entity unless current_user.password?

        unless current_user.authenticate(params[:password].to_s)
          return render json: { error: 'invalid_password' }, status: :unprocessable_entity
        end

        AccountDeletion::Scheduler.schedule!(current_user)
        render json: { deletion_scheduled_at: current_user.deletion_scheduled_at }
      end

      def destroy
        AccountDeletion::Scheduler.cancel!(current_user)
        head :no_content
      end
    end
  end
end
