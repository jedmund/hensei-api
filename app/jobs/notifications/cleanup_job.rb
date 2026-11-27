# frozen_string_literal: true

module Notifications
  # Nightly sweep that deletes notifications nobody needs anymore: rows read
  # more than RETENTION ago, and invitations or phantom assignments last
  # updated more than RETENTION ago that are resolved, read or not. Unread
  # passive rows and pending actionable rows (read or not) stay at any age.
  class CleanupJob < ApplicationJob
    queue_as :maintenance

    RETENTION = 90.days
    BATCH_SIZE = 1000

    def perform
      cutoff = RETENTION.ago

      read = Notification.where(read_at: ...cutoff).where.not(id: Notification.pending.select(:id))
                         .in_batches(of: BATCH_SIZE).delete_all
      resolved = Notification.resolved.where(updated_at: ...cutoff).in_batches(of: BATCH_SIZE).delete_all

      Rails.logger.info "[Notifications] Cleanup deleted #{read} read and #{resolved} resolved notifications"
    end
  end
end
