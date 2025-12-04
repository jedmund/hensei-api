# frozen_string_literal: true

module Api
  module V1
    class GwEventsController < Api::V1::ApiController
      before_action :restrict_access, only: %i[create update]
      before_action :require_admin!, only: %i[create update]
      before_action :set_event, only: %i[show update]

      # GET /gw_events
      def index
        events = GwEvent.order(start_date: :desc)
        render json: GwEventBlueprint.render(events, root: :gw_events)
      end

      # GET /gw_events/:id
      def show
        participation = current_user&.crew&.crew_gw_participations&.find_by(gw_event: @event)
        render json: GwEventBlueprint.render(@event, view: :with_participation, participation: participation, root: :gw_event)
      end

      # POST /gw_events (admin only)
      def create
        event = GwEvent.new(event_params)

        if event.save
          render json: GwEventBlueprint.render(event, root: :gw_event), status: :created
        else
          render_validation_error_response(event)
        end
      end

      # PUT /gw_events/:id (admin only)
      def update
        if @event.update(event_params)
          render json: GwEventBlueprint.render(@event, root: :gw_event)
        else
          render_validation_error_response(@event)
        end
      end

      private

      def set_event
        @event = GwEvent.find(params[:id])
      end

      def event_params
        params.require(:gw_event).permit(:element, :start_date, :end_date, :event_number)
      end

      def require_admin!
        raise Api::V1::UnauthorizedError unless current_user&.admin?
      end
    end
  end
end
