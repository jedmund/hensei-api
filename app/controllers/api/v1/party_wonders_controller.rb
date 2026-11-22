# frozen_string_literal: true

module Api
  module V1
    ##
    # PUT /parties/:id/wonders replaces a team's Wonders, like
    # PUT /parties/:id/blessings. POST /parties/:id/wonders/sync replaces them
    # with the account's current collection, as a new team's snapshot does. The party is loaded by its id and authorized
    # against its real owner or edit key; Wonders are looked up in the
    # catalogue, and no ownership fields are read from params.
    class PartyWondersController < Api::V1::ApiController
      include PartyAuthorizationConcern

      MAX_WONDERS = 100
      FIELDS = %i[level evolution possession].freeze

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_validation_error_response(e.record)
      end

      rescue_from ActiveRecord::RecordNotUnique do
        render_list_error('changed at the same time; try again')
      end

      before_action :set_party
      before_action :authorize_party!

      # PUT /parties/:id/wonders { wonders: [{ wonder_id, level, evolution, possession }] }
      def update
        entries = params[:wonders]
        return render_list_error('must be a list') unless entries.is_a?(Array)
        return render_list_error("can hold at most #{MAX_WONDERS} Wonders") if entries.size > MAX_WONDERS
        return render_list_error('must be objects') unless entries.all?(ActionController::Parameters)

        entries = entries.map { |entry| entry.permit(:wonder_id, *FIELDS) }
        ids = entries.map { |entry| entry[:wonder_id].to_s }
        wonders = Wonder.includes(:level_bonuses, :evolution_caps).where(id: ids).index_by(&:id)
        return render_list_error('include an unknown or repeated Wonder') if ids.uniq.size != ids.size || ids.any? { |id| wonders[id].nil? }

        replace!(entries, wonders)
        @party.mark_updated!
        render_wonders
      end

      # POST /parties/:id/wonders/sync
      # Reads the same account a new team's snapshot does (its collection
      # source, else its owner), and only when the requester may still see
      # that collection.
      def sync
        snapshot = PartyWonderSnapshot.new(@party)
        source = snapshot.source_user
        return render_list_error('this team has no account to sync from') unless source
        return render_forbidden_response('Collection is not accessible') unless source.collection_viewable_by?(current_user)

        Party.transaction do
          Party.where(id: @party.id).lock.pick(:id)
          snapshot.sync!
        end
        @party.mark_updated!
        render_wonders
      end

      private

      def render_wonders
        render json: { wonders: PartyWonderBlueprint.render_as_hash(@party.party_wonders.includes(wonder: :level_bonuses)) }
      end

      def set_party
        @party = Party.find_by(id: params[:id])
        render_not_found_response('party') unless @party
      end

      # Under the party's row lock, so two replaces run one after the other.
      # Symbolum's image variant can't be sent, so it's kept from the row it
      # replaces while the character count is unchanged.
      def replace!(entries, wonders)
        Party.transaction do
          Party.where(id: @party.id).lock.pick(:id)
          previous = @party.party_wonders.reload.index_by(&:wonder_id)
          @party.party_wonders.delete_all
          entries.each do |entry|
            wonder = wonders.fetch(entry[:wonder_id].to_s)
            attributes = entry.slice(*FIELDS).to_h.merge(wonder: wonder)
            old = previous[wonder.id]
            attributes[:image] = old.image if wonder.scaling? && old&.image.present? && old.possession.to_s == attributes['possession'].to_s
            @party.party_wonders.create!(attributes)
          end
        end
        @party.party_wonders.reset
      end

      def render_list_error(message)
        render json: ErrorBlueprint.render_as_json(nil, errors: { wonders: Array(message) }),
               status: :unprocessable_content
      end
    end
  end
end
