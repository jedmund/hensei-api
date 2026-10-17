# frozen_string_literal: true

module Api
  module V1
    # Gives, changes and removes the current user's sticker on a party.
    # `:id` is the party UUID. Only `sticker` (a slug) is read from params:
    # the giver is always the current user and the party always comes from
    # the path, and ownership is checked on the loaded row.
    class PartyStickersController < Api::V1::ApiController
      limit_requests 'party-sticker', to: 30, within: 1.minute, only: %i[update destroy],
                                      by: -> { current_user&.id || client_ip }

      before_action :doorkeeper_authorize!
      before_action :restrict_access
      before_action :set_party

      # PUT /parties/:id/sticker  { sticker: "<slug>" }
      def update
        return render_forbidden_response('You cannot give a sticker to your own team') if own_party?
        return render_unprocessable('Only public teams can receive stickers') unless @party.public?

        sticker = Sticker.active.find_by(slug: params[:sticker].to_s)
        return render_unprocessable('Unknown or inactive sticker') unless sticker

        party_sticker = PartySticker.find_or_initialize_by(user_id: current_user.id, party_id: @party.id)
        party_sticker.sticker = sticker
        party_sticker.save! if party_sticker.changed?

        render json: { sticker: sticker.slug }
      end

      # DELETE /parties/:id/sticker
      # Only ever removes the current user's own sticker.
      def destroy
        PartySticker.where(user_id: current_user.id, party_id: @party.id).destroy_all
        head :no_content
      end

      private

      def set_party
        @party = Party.find_by(id: params[:id].to_s[UUID_FORMAT])
        render_not_found_response('party') unless @party
      end

      def own_party?
        @party.user_id.present? && @party.user_id == current_user.id
      end

      def render_unprocessable(message)
        render json: { error: message }, status: :unprocessable_entity
      end
    end
  end
end
