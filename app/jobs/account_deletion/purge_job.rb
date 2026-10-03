# frozen_string_literal: true

module AccountDeletion
  # Daily sweep that deletes accounts whose deletion grace period has ended.
  # One account failing to purge is reported and doesn't stop the rest.
  class PurgeJob < ApplicationJob
    queue_as :maintenance

    def perform
      User.due_for_deletion.find_each do |user|
        AccountDeletion::Purge.call(user)
      rescue StandardError => e
        Rails.logger.error "[AccountDeletion] Purge failed for user #{user.id}: #{e.class}: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end
  end
end
