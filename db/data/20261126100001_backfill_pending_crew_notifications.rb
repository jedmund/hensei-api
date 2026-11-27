# frozen_string_literal: true

# Gives the crew invitations and phantom assignments that are waiting on
# someone a notification (GBF-82), so they show in the new feed. Idempotent:
# skips any that already have one.
class BackfillPendingCrewNotifications < ActiveRecord::Migration[8.1]
  def up
    CrewInvitation.active.find_each do |invitation|
      next if Notification.exists?(subject: invitation)

      Notification.create!(recipient_id: invitation.user_id, kind: :crew_invited, subject: invitation,
                           actor_id: invitation.invited_by_id,
                           created_at: invitation.created_at, updated_at: invitation.created_at)
    end

    PhantomPlayer.not_deleted.pending_confirmation.find_each do |phantom|
      next if Notification.exists?(subject: phantom)

      Notification.create!(recipient_id: phantom.claimed_by_id, kind: :phantom_assigned, subject: phantom,
                           group_key: "phantom:#{phantom.id}",
                           created_at: phantom.updated_at, updated_at: phantom.updated_at)
    end
  end

  def down
    # Can't tell these apart from notifications written since
  end
end
