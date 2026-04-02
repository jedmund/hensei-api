# frozen_string_literal: true

module Api
  module V1
    class EventsController < ApiController
      before_action :set_event, only: %i[show update destroy upload_banner]
      before_action :doorkeeper_authorize!, only: %i[create update destroy upload_banner]
      before_action :ensure_editor_role, only: %i[create update destroy upload_banner]

      def index
        events = Event.all
        events = events.by_type(params[:by_type]) if params[:by_type].present?
        events = events.order(start_time: :desc)

        render json: EventBlueprint.render(events)
      end

      def show
        if @event
          render json: EventBlueprint.render(@event)
        else
          render_not_found_response('event')
        end
      end

      def create
        event = Event.new(event_params)

        if event.save
          render json: EventBlueprint.render(event), status: :created
        else
          render_validation_error_response(event)
        end
      end

      def update
        if @event.update(event_params)
          render json: EventBlueprint.render(@event)
        else
          render_validation_error_response(@event)
        end
      end

      def destroy
        @event.destroy!
        head :no_content
      end

      def upload_banner
        return render_not_found_response('event') unless @event

        image_data = params[:image]
        return render json: { error: 'No image data provided' }, status: :unprocessable_entity if image_data.blank?

        decoded_image = Base64.decode64(image_data)
        s3_key = "images/events/#{@event.id}.png"

        aws = AwsService.new
        aws.upload_stream(StringIO.new(decoded_image), s3_key)

        @event.update!(banner_image: s3_key)

        render json: { success: true, url: s3_key }
      end

      private

      def set_event
        @event = Event.find_by(id: params[:id])
      end

      def event_params
        params.require(:event).permit(:name, :event_type, :start_time, :end_time, :element, :banner_image)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[EVENTS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
