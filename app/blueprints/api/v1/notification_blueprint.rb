# frozen_string_literal: true

module Api
  module V1
    # A notification for its recipient. Render with `related:` from
    # Notifications::Related (the stickers, remixes and events the payloads
    # point at, loaded at once).
    #
    # Sticker notifications never carry an actor. A remix names its remixer
    # and links to it only while the remix is public.
    class NotificationBlueprint < ApiBlueprint
      fields :kind, :count, :created_at, :updated_at

      field :read do |notification|
        notification.read_at.present?
      end

      # pending/accepted/... for invitations and phantoms, else null
      field :state, &:state

      field :actor do |notification, options|
        next nil if notification.sticker_received?
        next nil if notification.party_remixed? && NotificationBlueprint.public_remix(notification, options).nil?

        UserBlueprint.render_as_hash(notification.actor, view: :inline) if notification.actor
      end

      field :party do |notification|
        next nil unless notification.subject_type == 'Party'

        { shortcode: notification.subject.shortcode, name: notification.subject.name }
      end

      field :remix do |notification, options|
        remix = NotificationBlueprint.public_remix(notification, options) if notification.party_remixed?
        { shortcode: remix.shortcode, name: remix.name } if remix
      end

      field :sticker do |notification, options|
        next nil unless notification.sticker_received?

        sticker = options[:related].stickers[notification.payload['sticker_id']]
        StickerBlueprint.render_as_hash(sticker) if sticker
      end

      field :event do |notification, options|
        event = options[:related].events[notification.payload['event_id']] if notification.party_featured?
        { id: event.id, name: { en: event.name_en, ja: event.name_jp } } if event
      end

      field :crew do |notification|
        crew = notification.subject.crew if notification.actionable?
        { id: crew.id, name: crew.name, gamertag: crew.gamertag } if crew
      end

      field :invitation_id do |notification|
        notification.subject_id if notification.crew_invited?
      end

      field :phantom do |notification|
        next nil unless notification.phantom_assigned?

        { id: notification.subject.id, name: notification.subject.name }
      end

      def self.public_remix(notification, options)
        remix = options[:related].remixes[notification.payload['remix_id']]
        remix if remix&.public?
      end
    end
  end
end
