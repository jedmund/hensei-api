# frozen_string_literal: true

module Api
  module V1
    class EventsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy upload_banner]
      before_action :ensure_editor_role, only: %i[create update destroy upload_banner]
      before_action :set_event, only: %i[show update destroy upload_banner]

      # GET /events
      def index
        events = Event.order(start_time: :desc)
        events = events.by_type(params[:event_type]) if params[:event_type].present?
        render json: EventBlueprint.render(events, root: :events)
      end

      # GET /events/:id
      def show
        render json: EventBlueprint.render(@event, root: :event)
      end

      # POST /events
      def create
        event = Event.new(event_params)
        if event.save
          render json: EventBlueprint.render(event, root: :event), status: :created
        else
          render_validation_error_response(event)
        end
      end

      # PUT /events/:id
      def update
        if @event.update(event_params)
          render json: EventBlueprint.render(@event, root: :event)
        else
          render_validation_error_response(@event)
        end
      end

      # DELETE /events/:id
      def destroy
        @event.destroy
        head :no_content
      end

      # POST /events/:id/upload_banner
      def upload_banner
        image_data = params[:image]
        return render json: { error: 'No image data provided' }, status: :unprocessable_entity if image_data.blank?

        decoded_image = Base64.decode64(image_data)
        s3_key = "images/events/#{@event.id}.png"

        aws = AwsService.new
        aws.upload_stream(StringIO.new(decoded_image), s3_key)

        @event.update!(banner_image: s3_key)

        render json: EventBlueprint.render(@event, root: :event)
      end

      private

      def set_event
        @event = Event.find_by(id: params[:id])
        render_not_found_response('event') unless @event
      end

      def event_params
        params.require(:event).permit(:name, :event_type, :start_time, :end_time, :element)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[EVENTS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
