# frozen_string_literal: true

module Api
  module V1
    # Game events. The public sees approved events; editors see and manage
    # all of them, and get the sync bookkeeping fields.
    class EventsController < Api::V1::ApiController
      include EditorImageUpload

      EDITOR_ACTIONS = %i[create update approve hide upload_image sync].freeze
      SCOPES = %w[current upcoming past].freeze
      MAX_IMAGE_DIMENSION = 2048
      MAX_IMAGE_BYTES = 2 * 1024 * 1024

      before_action :doorkeeper_authorize!, only: EDITOR_ACTIONS
      before_action :ensure_editor_role, only: EDITOR_ACTIONS
      before_action :set_event, only: %i[show update approve hide upload_image]

      # GET /events?scope=current|upcoming|past&kind=…
      # Editors may pass status=draft|approved|hidden|all.
      def index
        events = filter_by_status(Event.includes(event_raids: { raid: :group }))
        events = filter_by_kind(events)
        events = filter_by_scope(events)

        render json: EventBlueprint.render(events, root: :events, editor: editor_role?)
      end

      # GET /events/:id
      def show
        return render_not_found_response('event') unless @event.approved? || editor_role?

        render_event
      end

      # POST /events
      # Editor-created events land as drafts; approve them separately.
      def create
        event = Event.new(event_attributes)
        saved = Event.transaction do
          next false unless event.save
          next true unless params[:event].key?(:raid_ids)

          event.assign_raid_ids(params[:event][:raid_ids]) || raise(ActiveRecord::Rollback)
        end

        return render_validation_error_response(event) unless saved

        @event = event
        render_event(status: :created)
      end

      # PUT /events/:id
      def update
        saved = Event.transaction do
          next false unless @event.update(event_attributes)
          next true unless params[:event].key?(:raid_ids)

          @event.assign_raid_ids(params[:event][:raid_ids]) || raise(ActiveRecord::Rollback)
        end

        return render_validation_error_response(@event) unless saved

        render_event
      end

      # POST /events/:id/approve
      def approve
        @event.update!(status: :approved)
        render_event
      end

      # POST /events/:id/hide
      def hide
        @event.update!(status: :hidden)
        render_event
      end

      # POST /events/:id/upload_image
      # Multipart `image` (PNG, WebP or JPEG), stored at events/<id>.<ext>.
      def upload_image
        stored = store_editor_image(@event, prefix: Event::IMAGE_PREFIX, name: @event.id,
                                            formats: %w[PNG WEBP JPEG],
                                            max_dimension: MAX_IMAGE_DIMENSION,
                                            max_bytes: MAX_IMAGE_BYTES)
        return unless stored

        render_event
      end

      # POST /events/sync
      def sync
        Events::ScheduleSyncJob.perform_later(current_user.id)
        render json: { queued: true }, status: :accepted
      end

      private

      def set_event
        @event = Event.includes(event_raids: { raid: :group }).find_by(id: params[:id].to_s[UUID_FORMAT])
        render_not_found_response('event') unless @event
      end

      def render_event(status: :ok)
        event = Event.includes(event_raids: { raid: :group }).find(@event.id)
        render json: EventBlueprint.render(event, editor: editor_role?), status: status
      end

      def filter_by_status(events)
        return events.approved unless editor_role? && params[:status].present?
        return events if params[:status] == 'all'
        return events.where(status: params[:status]) if Event.statuses.key?(params[:status])

        events.approved
      end

      def filter_by_kind(events)
        return events if params[:kind].blank?
        return events.none unless Event.kinds.key?(params[:kind])

        events.where(kind: params[:kind])
      end

      def filter_by_scope(events)
        case params[:scope]
        when 'current' then events.current.order(:starts_at)
        when 'upcoming' then events.upcoming.order(:starts_at)
        when 'past' then events.past.order(starts_at: :desc)
        else events.order(starts_at: :desc)
        end
      end

      def event_attributes
        attrs = params.require(:event).permit(:name_en, :name_jp, :kind, :series, :element, :starts_at,
                                              :ends_at, :event_number)
        attrs[:series] = attrs[:series].presence if attrs.key?(:series)
        attrs[:element] = Event.normalize_element(attrs[:element]) if attrs.key?(:element)
        attrs
      end
    end
  end
end
