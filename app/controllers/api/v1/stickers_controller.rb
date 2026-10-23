# frozen_string_literal: true

module Api
  module V1
    # The sticker catalogue. Reading is public; editors manage it.
    class StickersController < Api::V1::ApiController
      include EditorImageUpload
      include UploadSizeLimit

      EDITOR_ACTIONS = %i[create update destroy upload_image remove_image reorder library].freeze
      MAX_IMAGE_DIMENSION = 512
      MAX_IMAGE_BYTES = 512 * 1024
      # Room for a base64-encoded image (a third larger) and the form around it.
      UPLOAD_REQUEST_MAX_BYTES = 768 * 1024

      limit_upload_size UPLOAD_REQUEST_MAX_BYTES, only: :upload_image

      before_action :doorkeeper_authorize!, only: EDITOR_ACTIONS
      before_action :ensure_editor_role, only: EDITOR_ACTIONS
      before_action :set_sticker, only: %i[update destroy upload_image remove_image]
      before_action :set_library_entry, only: %i[create update]

      # GET /stickers
      # Active stickers in picker order. Editors may pass include_inactive=true.
      def index
        return render json: render_editor(Sticker.ordered, root: :stickers) if include_inactive?

        payload = Rails.cache.fetch(Sticker::CATALOGUE_CACHE_KEY, expires_in: 1.hour) do
          StickerBlueprint.render_as_hash(Sticker.active.ordered, root: :stickers)
        end
        render json: payload
      end

      # GET /stickers/library
      # The game's stickers editors can pick from, each with the catalogue
      # sticker already made from it (sticker_id), if any.
      def library
        used = Sticker.where(image_key: StickerLibrary.all.map(&:image_key)).pluck(:image_key, :id).to_h
        render json: {
          library: StickerLibrary.all.map do |entry|
            {
              id: entry.id, label: entry.label, section: entry.section, group: entry.group,
              image_url: entry.image_key, image_url_ja: entry.image_key_jp,
              sticker_id: used[entry.image_key]
            }
          end
        }
      end

      # POST /stickers
      # `library_id` takes its images from that library sticker.
      def create
        sticker = Sticker.new(sticker_params)
        use_library_images(sticker)
        if sticker.save
          render json: render_editor(sticker), status: :created
        else
          render_validation_error_response(sticker)
        end
      end

      # PUT /stickers/:id
      # `library_id` swaps its images for that library sticker's.
      def update
        @sticker.assign_attributes(sticker_params)
        use_library_images(@sticker)
        if @sticker.save
          render json: render_editor(@sticker)
        else
          render_validation_error_response(@sticker)
        end
      end

      # DELETE /stickers/:id
      # Rejected once anyone has given the sticker; retire it with active=false.
      def destroy
        if @sticker.destroy
          head :no_content
        else
          render json: { error: 'This sticker has been given and cannot be deleted. Deactivate it instead.' },
                 status: :unprocessable_entity
        end
      end

      # POST /stickers/:id/upload_image
      # Multipart `image` (PNG or WebP), stored at icons/stickers/<slug>.<ext>,
      # or with `language=ja` as the Japanese image at <slug>.ja.<ext>.
      def upload_image
        japanese = params[:language].to_s == 'ja'
        stored = store_editor_image(@sticker, prefix: Sticker::IMAGE_PREFIX,
                                              name: japanese ? "#{@sticker.slug}.ja" : @sticker.slug,
                                              column: japanese ? :image_key_jp : :image_key,
                                              formats: %w[PNG WEBP],
                                              max_dimension: MAX_IMAGE_DIMENSION,
                                              max_bytes: MAX_IMAGE_BYTES)
        return unless stored

        render json: render_editor(@sticker)
      end

      # DELETE /stickers/:id/image?language=ja
      # Removes the Japanese image, so Japanese viewers see the English one.
      # Its file is deleted only if it's the sticker's own, never a shared
      # library image. The English image can be replaced but not removed.
      def remove_image
        unless params[:language].to_s == 'ja'
          return render json: { error: 'Only the Japanese image can be removed' }, status: :unprocessable_entity
        end

        previous_key = @sticker.image_key_jp
        @sticker.update!(image_key_jp: nil)
        remove_replaced_image(previous_key) if owned_image?(previous_key, Sticker::IMAGE_PREFIX, "#{@sticker.slug}.ja")
        render json: render_editor(@sticker)
      end

      # PUT /stickers/reorder
      # { ids: [uuid, …] } sets positions in the given order.
      def reorder
        ids = Array(params[:ids]).map(&:to_s).uniq
        stickers = Sticker.where(id: ids.grep(UUID_FORMAT)).index_by(&:id)
        missing = ids - stickers.keys
        if missing.any?
          return render json: { error: "Unknown sticker ids: #{missing.join(', ')}" }, status: :unprocessable_entity
        end

        Sticker.transaction do
          ids.each_with_index { |id, index| stickers[id].update!(position: index) }
        end

        render json: render_editor(Sticker.ordered, root: :stickers)
      end

      private

      # The editor view, with whether each sticker can be deleted
      def render_editor(stickers, **)
        given = PartySticker.where(sticker_id: Array(stickers).map(&:id)).distinct.pluck(:sticker_id).to_set
        StickerBlueprint.render(stickers, view: :editor, given_sticker_ids: given, **)
      end

      def set_sticker
        @sticker = Sticker.find_by(id: params[:id].to_s[UUID_FORMAT])
        render_not_found_response('sticker') unless @sticker
      end

      def include_inactive?
        ActiveModel::Type::Boolean.new.cast(params[:include_inactive]) && editor_role?
      end

      # The library sticker named by `library_id`, if any; 422 for an unknown one
      def set_library_entry
        id = params.dig(:sticker, :library_id)
        return if id.blank?

        @library_entry = StickerLibrary.find(id)
        render json: { error: 'Unknown library sticker' }, status: :unprocessable_entity unless @library_entry
      end

      def use_library_images(sticker)
        return unless @library_entry

        sticker.assign_attributes(image_key: @library_entry.image_key, image_key_jp: @library_entry.image_key_jp)
      end

      def sticker_params
        params.require(:sticker).permit(:slug, :meaning_en, :meaning_jp, :position, :active)
      end
    end
  end
end
