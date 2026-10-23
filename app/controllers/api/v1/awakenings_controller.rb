# frozen_string_literal: true

module Api
  module V1
    class AwakeningsController < Api::V1::ApiController
      include EditorImageUpload
      include UploadSizeLimit

      # The game's awakening icons are 80x80 PNGs of about 3KB, so these leave
      # plenty of room while keeping uploads icon-sized.
      MAX_IMAGE_DIMENSION = 128
      MAX_IMAGE_BYTES = 64 * 1024
      # Base64 adds about a third to the image, plus the JSON around it.
      UPLOAD_REQUEST_MAX_BYTES = 128 * 1024

      limit_upload_size UPLOAD_REQUEST_MAX_BYTES, only: :upload_image
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
      # Body: { image: <base64-png>, filename: <string?> }
      # Stored at icons/awakening/<slug>.png, where the web app reads it.
      def upload_image
        awakening = Awakening.find_by(id: params[:id])
        return render_not_found_response('awakening') unless awakening

        unless awakening.slug.to_s.match?(Awakening::SLUG_FORMAT)
          return render json: { error: 'Awakening slug is invalid' }, status: :unprocessable_entity
        end

        bytes = uploaded_image_bytes(params[:image])
        result = IconUploadValidator.call(bytes, max_dimension: MAX_IMAGE_DIMENSION, max_bytes: MAX_IMAGE_BYTES)
        return render json: { error: result.error }, status: :unprocessable_entity unless result.valid?

        IconStorage.put("#{Awakening::IMAGE_PREFIX}/#{awakening.slug}.#{result.extension}", bytes,
                        content_type: result.content_type)
        awakening.touch

        render json: AwakeningBlueprint.render(awakening)
      end

      private

      def awakening_params
        params.require(:awakening).permit(:name_en, :name_jp, :slug, :object_type, :order)
      end
    end
  end
end
