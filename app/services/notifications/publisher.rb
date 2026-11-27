# frozen_string_literal: true

module Notifications
  # Writes notifications for the events in GBF-82. Called from model
  # callbacks, so it never raises: a failed notification is reported and
  # the action that caused it still succeeds.
  #
  # Nobody is told about something they did themselves, or about a team
  # with no owner.
  module Publisher
    module_function

    # A giver's first sticker on a team. Changing or moving it doesn't come
    # here (the row is updated, not created). Repeats group into the unread
    # row, which counts givers, so removing and re-adding one doesn't count
    # twice. Givers are never stored: the row keeps keyed digests only, to
    # tell repeats apart, and they are never serialized.
    def sticker_received(party_sticker)
      safely do
        party = party_sticker.party
        recipient_id = party&.user_id
        next if recipient_id.nil? || recipient_id == party_sticker.user_id

        key = "sticker:#{party.id}"
        giver = giver_digest(party, party_sticker.user_id)
        row = unread_row(recipient_id, key)
        if row
          givers = Array(row.payload['givers'])
          next if givers.include?(giver)

          givers << giver
          row.update!(count: givers.size,
                      payload: row.payload.merge('givers' => givers, 'sticker_id' => party_sticker.sticker_id))
        else
          Notification.create!(recipient_id: recipient_id, kind: :sticker_received, subject: party, group_key: key,
                               payload: { 'givers' => [giver], 'sticker_id' => party_sticker.sticker_id })
        end
      end
    end

    # Someone remixed a team. Repeats group into the unread row, and the same
    # person remixing it again doesn't notify. Whether the remixer is shown
    # is decided when rendering (only while the remix is public).
    def party_remixed(remix)
      safely do
        source = remix.source_party
        recipient_id = source&.user_id
        next if recipient_id.nil? || recipient_id == remix.user_id
        next if remix.user_id && source.remixes.where(user_id: remix.user_id).where.not(id: remix.id).exists?

        key = "remix:#{source.id}"
        row = unread_row(recipient_id, key)
        if row
          row.update!(count: row.count + 1, actor_id: remix.user_id,
                      payload: row.payload.merge('remix_id' => remix.id))
        else
          Notification.create!(recipient_id: recipient_id, kind: :party_remixed, subject: source, group_key: key,
                               actor_id: remix.user_id, payload: { 'remix_id' => remix.id })
        end
      end
    end

    def party_featured(featured)
      safely do
        recipient_id = featured.party&.user_id
        next if recipient_id.nil?

        Notification.create!(recipient_id: recipient_id, kind: :party_featured, subject: featured.party,
                             payload: { 'event_id' => featured.event_id }.compact)
      end
    end

    def crew_invited(invitation)
      safely do
        next if invitation.user_id == invitation.invited_by_id

        Notification.create!(recipient_id: invitation.user_id, kind: :crew_invited, subject: invitation,
                             actor_id: invitation.invited_by_id)
      end
    end

    # Assigning a phantom to someone again reuses their row for it, so it
    # never shows twice as pending.
    def phantom_assigned(phantom, actor: nil)
      safely do
        recipient_id = phantom.claimed_by_id
        next if recipient_id.nil? || recipient_id == actor&.id

        key = "phantom:#{phantom.id}"
        row = Notification.find_by(recipient_id: recipient_id, group_key: key)
        if row
          row.update!(read_at: nil, actor_id: actor&.id, updated_at: Time.current)
        else
          Notification.create!(recipient_id: recipient_id, kind: :phantom_assigned, subject: phantom,
                               group_key: key, actor_id: actor&.id)
        end
      end
    end

    def unread_row(recipient_id, key)
      Notification.unread.where(recipient_id: recipient_id, group_key: key).order(created_at: :desc).first
    end

    # Per team, so digests can't be matched across teams
    def giver_digest(party, user_id)
      OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, "#{party.id}:#{user_id}")[0, 16]
    end

    # A savepoint, so a failed write doesn't abort a caller's transaction
    # (a phantom assigned inside CrewInvitation#accept!)
    def safely(&)
      Notification.transaction(requires_new: true, &)
    rescue StandardError => e
      Rails.error.report(e, handled: true, context: { source: 'notifications' })
      nil
    end
  end
end
