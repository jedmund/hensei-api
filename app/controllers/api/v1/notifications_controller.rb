# frozen_string_literal: true

module Api
  module V1
    # The current user's notifications (GBF-82). Every action is scoped to
    # current_user, so someone else's notification is a 404.
    class NotificationsController < Api::V1::ApiController
      PER_PAGE = 20
      MAX_PER_PAGE = 50

      before_action :restrict_access

      # GET /notifications?page=&per_page=
      def index
        per_page = params[:per_page].to_i.clamp(1, MAX_PER_PAGE) if params[:per_page].present?
        notifications = current_user.notifications.newest_first
                                    .paginate(page: params[:page], per_page: per_page || PER_PAGE)

        related = Notifications::Related.new(notifications)
        render json: {
          # A row whose subject is gone (deleted without callbacks) is skipped
          notifications: NotificationBlueprint.render_as_hash(notifications.select(&:subject), related: related),
          meta: pagination_meta(notifications),
          unread_count: Notification.unread_count_for(current_user)
        }
      end

      # GET /notifications/unread_count
      def unread_count
        render json: { unread_count: Notification.unread_count_for(current_user) }
      end

      # POST /notifications/seen: the jewel was opened
      def seen
        current_user.update_column(:notifications_seen_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
        unread_count
      end

      # POST /notifications/:id/read
      def read
        notification = current_user.notifications.find(params.expect(:id))
        # Not touching updated_at, which orders the feed
        notification.update_column(:read_at, Time.current) if notification.read_at.nil? # rubocop:disable Rails/SkipsModelValidations
        head :no_content
      end

      # POST /notifications/read_all
      def read_all
        current_user.notifications.unread.update_all(read_at: Time.current)
        head :no_content
      end
    end
  end
end
