# frozen_string_literal: true

module Api
  module V1
    # Staff picks. Editor-only; the public reads them through GET /home.
    class FeaturedPartiesController < Api::V1::ApiController
      include PartyQueryingConcern

      before_action :doorkeeper_authorize!
      before_action :ensure_editor_role
      before_action :set_featured_party, only: %i[update destroy]

      # GET /featured_parties?event_id=<uuid>
      # All picks, or one event's, ordered by position.
      def index
        picks = FeaturedParty.order(:position, :created_at)
        picks = picks.where(event_id: params[:event_id].to_s[UUID_FORMAT]) if params[:event_id].present?
        picks = picks.to_a

        parties = build_preview_base_query.where(id: picks.map(&:party_id)).index_by(&:id)
        picks.each { |pick| pick.association(:party).target = parties[pick.party_id] }
        options = sticker_options(parties.values)

        render json: FeaturedPartyBlueprint.render(picks, root: :featured_parties, **options)
      end

      # POST /featured_parties
      def create
        featured = FeaturedParty.new(featured_party_params)
        return render_validation_error_response(featured) unless featured.save

        render_featured(featured, status: :created)
      end

      # PUT /featured_parties/:id
      def update
        return render_validation_error_response(@featured) unless @featured.update(featured_party_params)

        render_featured(@featured)
      end

      # DELETE /featured_parties/:id
      def destroy
        @featured.destroy!
        head :no_content
      end

      private

      def set_featured_party
        @featured = FeaturedParty.find_by(id: params[:id].to_s[UUID_FORMAT])
        render_not_found_response('featured party') unless @featured
      end

      def render_featured(featured, status: :ok)
        party = build_preview_base_query.find(featured.party_id)
        featured.association(:party).target = party
        options = sticker_options([party])
        render json: FeaturedPartyBlueprint.render(featured, **options), status: status
      end

      # Each pick renders its party as an association, which doesn't batch its
      # own sticker lookups, so they're looked up for all the parties here
      def sticker_options(parties)
        PartyStickerSummary.batch_options(parties, current_user).merge(current_user: current_user)
      end

      def featured_party_params
        attrs = params.require(:featured_party).permit(:event_id, :party_id, :position, :note_en, :note_jp)
        attrs[:event_id] = nil if attrs.key?(:event_id) && attrs[:event_id].blank?
        attrs
      end
    end
  end
end
