# frozen_string_literal: true

module Api
  module V1
    # Guild Wars for the crew pages. Each is an Event of kind unite_and_fight,
    # rendered in the GW shape (JST start_date and end_date, event_number).
    class GwEventsController < Api::V1::ApiController
      before_action :restrict_access, only: %i[create update]
      before_action :require_admin!, only: %i[create update]
      before_action :set_event, only: %i[show update]

      # GET /gw_events/status
      def status
        events = Event.unite_and_fight.approved.where.not(event_number: nil)
        upcoming = events.upcoming.order(:starts_at).first
        recent = events.current.order(starts_at: :desc).first || events.recently_ended.first

        render json: {
          upcoming: upcoming ? GwEventBlueprint.render_as_hash(upcoming) : nil,
          recent: recent ? GwEventBlueprint.render_as_hash(recent) : nil
        }
      end

      # GET /gw_events
      def index
        events = Event.unite_and_fight.approved.where.not(event_number: nil).order(starts_at: :desc)

        # If user has a crew, include participation data for each event
        participations_by_event = {}
        if current_user&.crew
          participations = current_user.crew.crew_gw_participations.includes(:gw_individual_scores)
          participations.each do |p|
            participations_by_event[p.event_id] = p
          end
        end

        render json: GwEventBlueprint.render(events, root: :gw_events, participations: participations_by_event)
      end

      # GET /gw_events/:id
      def show
        participation = current_user&.crew&.crew_gw_participations&.find_by(event: @event)
        render json: GwEventBlueprint.render(@event, view: :with_participation, participation: participation, root: :gw_event)
      end

      # POST /gw_events (admin only)
      # Guild Wars made here are live straight away, like events made by hand.
      def create
        attrs = event_attributes
        return if performed?

        event = Event.new(attrs.merge(kind: :unite_and_fight, series: 'unite_and_fight', status: :approved))
        event.name_en ||= default_name(event.event_number)
        event.name_jp ||= default_name_jp(event.event_number)

        if event.save
          render json: GwEventBlueprint.render(event, root: :gw_event), status: :created
        else
          render_validation_error_response(event)
        end
      end

      # PUT /gw_events/:id (admin only)
      def update
        attrs = event_attributes
        return if performed?

        # Keep a generated name in step with the number.
        attrs[:name_en] = default_name(attrs[:event_number]) if attrs.key?(:event_number) && @event.name_en == default_name(@event.event_number)
        attrs[:name_jp] = default_name_jp(attrs[:event_number]) if attrs.key?(:event_number) && @event.name_jp == default_name_jp(@event.event_number)
        @event.assign_attributes(attrs)

        if @event.save
          render json: GwEventBlueprint.render(@event, root: :gw_event)
        else
          render_validation_error_response(@event)
        end
      end

      private

      def set_event
        @event = Event.unite_and_fight.find(params[:id])
      end

      # Maps the GW fields onto the event: element by name or number, and the
      # JST days onto starts_at/ends_at. Renders a 422 for an unparseable date.
      def event_attributes
        permitted = params.require(:gw_event).permit(:element, :start_date, :end_date, :event_number)
        attrs = permitted.slice(:event_number).to_h.symbolize_keys
        attrs[:element] = Event.normalize_element(permitted[:element]) if permitted.key?(:element)
        attrs.merge(Event.gw_window(permitted[:start_date], permitted[:end_date]))
      rescue Date::Error
        render_unprocessable_entity_response(start_date: ['is not a valid date'])
        {}
      end

      def default_name(event_number)
        "Unite and Fight ##{event_number}"
      end

      def default_name_jp(event_number)
        "星の古戦場 第#{event_number}回"
      end

      def require_admin!
        raise Api::V1::UnauthorizedError unless current_user&.admin?
      end
    end
  end
end
