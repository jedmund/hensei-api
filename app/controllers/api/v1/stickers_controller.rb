# frozen_string_literal: true

module Api
  module V1
    # The sticker catalogue. Reading is public; editors manage it.
    class StickersController < Api::V1::ApiController
      include EditorImageUpload

      EDITOR_ACTIONS = %i[create update destroy upload_image reorder].freeze
      MAX_IMAGE_DIMENSION = 512
      MAX_IMAGE_BYTES = 512 * 1024

      before_action :doorkeeper_authorize!, only: EDITOR_ACTIONS
      before_action :ensure_editor_role, only: EDITOR_ACTIONS
      before_action :set_sticker, only: %i[update destroy upload_image]

      # GET /stickers
      # Active stickers in picker order. Editors may pass include_inactive=true.
      def index
        return render json: render_editor(Sticker.ordered, root: :stickers) if include_inactive?

        payload = Rails.cache.fetch(Sticker::CATALOGUE_CACHE_KEY, expires_in: 1.hour) do
          StickerBlueprint.render_as_hash(Sticker.active.ordered, root: :stickers)
        end
        render json: payload
      end

      # POST /stickers
      def create
        sticker = Sticker.new(sticker_params)
        if sticker.save
          render json: render_editor(sticker), status: :created
        else
          render_validation_error_response(sticker)
        end
      end

      # PUT /stickers/:id
      def update
        if @sticker.update(sticker_params)
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

      def sticker_params
        params.require(:sticker).permit(:slug, :meaning_en, :meaning_jp, :position, :active)
      end
    end
  end
end
