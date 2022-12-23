# frozen_string_literal: true

module Api
  module V1
    class GridSummonsController < Api::V1::ApiController
      def create
        party = Party.find(summon_params[:party_id])
        canonical_summon = Summon.find(summon_params[:summon_id])

        render_unauthorized_response if current_user && (party.user != current_user)

        if (grid_summon = GridSummon.where(
          party_id: party.id,
          position: summon_params[:position]
        ).first)
          GridSummon.destroy(grid_summon.id)
        end

        summon = GridSummon.create!(summon_params.merge(party_id: party.id, summon_id: canonical_summon.id))
        render json: GridSummonBlueprint.render(summon, view: :nested), status: :created if summon.save!
      end

      def update_uncap_level
        summon = GridSummon.find(summon_params[:id])

        render_unauthorized_response if current_user && (summon.party.user != current_user)

        summon.uncap_level = summon_params[:uncap_level]
        return unless summon.save!

        render json: GridSummonBlueprint.render(summon, view: :nested, root: :grid_summon)
      end

      # TODO: Implement removing summons
      def destroy; end

      private

      # Specify whitelisted properties that can be modified.
      def summon_params
        params.require(:summon).permit(:id, :party_id, :summon_id, :position, :main, :friend, :uncap_level)
      end
    end
  end
end
