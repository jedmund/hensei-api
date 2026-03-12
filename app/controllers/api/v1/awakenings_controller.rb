# frozen_string_literal: true

module Api
  module V1
    class AwakeningsController < Api::V1::ApiController
      before_action :doorkeeper_authorize!, only: %i[create update destroy upload_image]
      before_action :ensure_editor_role, only: %i[create update destroy upload_image]

      # GET /awakenings
      # Optional filter: ?object_type=Weapon
      def index
        awakenings = Awakening.all
        awakenings = awakenings.where(object_type: params[:object_type]) if params[:object_type].present?
        awakenings = awakenings.order(:object_type, :order)
        render json: AwakeningBlueprint.render(awakenings)
      end

      # GET /awakenings/:id
      def show
        awakening = Awakening.find_by(id: params[:id])
        return render_not_found_response('awakening') unless awakening

        render json: AwakeningBlueprint.render(awakening)
      end

      # POST /awakenings
      def create
        awakening = Awakening.new(awakening_params)
        if awakening.save
          render json: AwakeningBlueprint.render(awakening), status: :created
        else
          render_validation_error_response(awakening)
        end
      end

      # PUT /awakenings/:id
      def update
        awakening = Awakening.find_by(id: params[:id])
        return render_not_found_response('awakening') unless awakening

        if awakening.update(awakening_params)
          render json: AwakeningBlueprint.render(awakening)
        else
          render_validation_error_response(awakening)
        end
      end

      # DELETE /awakenings/:id
      def destroy
        awakening = Awakening.find_by(id: params[:id])
        return render_not_found_response('awakening') unless awakening

        awakening.destroy
        head :no_content
      end

      # POST /awakenings/:id/upload_image
      def upload_image
        awakening = Awakening.find_by(id: params[:id])
        return render_not_found_response('awakening') unless awakening

        image_data = params[:image]
        content_type = params[:content_type] || 'image/png'

        return render json: { error: 'No image data provided' }, status: :unprocessable_entity if image_data.blank?

        decoded_image = Base64.decode64(image_data)
        s3_key = "images/awakening/#{awakening.slug}.png"

        aws = AwsService.new
        aws.upload_stream(StringIO.new(decoded_image), s3_key)

        render json: { success: true, url: s3_key }
      end

      private

      def awakening_params
        params.require(:awakening).permit(:name_en, :name_jp, :slug, :object_type, :order)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[AWAKENINGS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end
