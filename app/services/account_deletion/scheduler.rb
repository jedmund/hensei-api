# frozen_string_literal: true

module AccountDeletion
  # Schedules and cancels self-serve account deletion. A scheduled account
  # keeps working for the grace period so its owner can log in and cancel;
  # AccountDeletion::PurgeJob deletes it once the date passes.
  module Scheduler
    class << self
      # Signs the user out everywhere, so the next login (where the cancel
      # banner shows) is a deliberate one. Calling it again keeps the original
      # date.
      def schedule!(user)
        scheduled = user.with_lock do
          next false if user.deletion_scheduled?

          user.update_columns(deletion_scheduled_at: User::DELETION_GRACE_PERIOD.from_now)
          true
        end

        sign_out_everywhere(user)
        SendAccountDeletionEmailJob.perform_later(user.id, 'scheduled') if scheduled
        user
      end

      def cancel!(user)
        cancelled = user.with_lock do
          next false unless user.deletion_scheduled?

          user.update_columns(deletion_scheduled_at: nil)
          true
        end

        SendAccountDeletionEmailJob.perform_later(user.id, 'cancelled') if cancelled
        user
      end

      private

      def sign_out_everywhere(user)
        Doorkeeper::AccessToken.where(resource_owner_id: user.id).delete_all
        Doorkeeper::AccessGrant.where(resource_owner_id: user.id).delete_all
        user.extension_auth_codes.delete_all
      end
    end
  end
end
