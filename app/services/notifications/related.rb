# frozen_string_literal: true

module Notifications
  # Loads what a page of notifications points at, so rendering them is a
  # fixed number of queries: actors, subjects (with crews), and the
  # stickers, remixes and events named in payloads.
  class Related
    attr_reader :stickers, :remixes, :events

    def initialize(notifications)
      notifications = notifications.to_a
      ActiveRecord::Associations::Preloader.new(records: notifications, associations: %i[actor subject]).call
      actionable = notifications.select(&:actionable?).map(&:subject)
      ActiveRecord::Associations::Preloader.new(records: actionable, associations: :crew).call

      @stickers = index(Sticker, notifications, 'sticker_id')
      @remixes = index(Party, notifications, 'remix_id')
      @events = index(Event, notifications, 'event_id')
    end

    private

    def index(model, notifications, key)
      ids = notifications.filter_map { |n| n.payload[key] }.uniq
      ids.empty? ? {} : model.where(id: ids).index_by(&:id)
    end
  end
end
