# frozen_string_literal: true

module Api
  module V1
    class GridSummonsController < Api::V1::ApiController
      attr_reader :party, :incoming_summon
      
      before_action :set, only: %w[update destroy]
      before_action :find_party, only: :create
      before_action :find_incoming_summon, only: :create
      before_action :authorize, only: %i[create update destroy]

      def create
        # Create the GridSummon with the desired parameters
        summon = GridSummon.new
        summon.attributes = summon_params.merge(party_id: party.id, summon_id: incoming_summon.id)

        if summon.validate
          save_summon(summon)
        else
          handle_conflict(summon)
        end
      end

      def update
        @summon.attributes = summon_params

        return render json: GridSummonBlueprint.render(@summon, view: :nested, root: :grid_summon) if @summon.save

        render_validation_error_response(@character)
      end

      def save_summon(summon)
        if (grid_summon = GridSummon.where(
          party_id: party.id,
          position: summon_params[:position]
        ).first)
          GridSummon.destroy(grid_summon.id)
        end

        return unless summon.save

        output = render_grid_summon_view(summon)
        render json: output, status: :created
      end

      def handle_conflict(summon)
        conflict_summon = summon.conflicts(party)
        ap conflict_summon
        return unless conflict_summon.summon.id == incoming_summon.id

        old_position = conflict_summon.position
        conflict_summon.position = summon_params[:position]

        return unless conflict_summon.save

        output = render_grid_summon_view(conflict_summon, old_position)
        render json: output
      end

      def update_uncap_level
        summon = GridSummon.find(summon_params[:id])

        render_unauthorized_response if current_user && (summon.party.user != current_user)

        summon.uncap_level = summon_params[:uncap_level]
        summon.transcendence_step = 0

        return unless summon.save!

        render json: GridSummonBlueprint.render(summon, view: :nested, root: :grid_summon)
      end

      def destroy
        render_unauthorized_response if @summon.party.user != current_user
        return render json: GridSummonBlueprint.render(@summon, view: :destroyed) if @summon.destroy
      end

      private

      def find_incoming_summon
        @incoming_summon = Summon.find_by(id: summon_params[:summon_id])
      end

      def find_party
        # BUG: I can create grid weapons even when I'm not logged in on an authenticated party
        @party = Party.find(summon_params[:party_id])
        render_unauthorized_response if current_user && (party.user != current_user)
      end

      def render_grid_summon_view(grid_summon, conflict_position = nil)
        GridSummonBlueprint.render(grid_summon, view: :nested,
                                   root: :grid_summon,
                                   meta: { replaced: conflict_position })
      end

      def authorize
        # Create
        unauthorized_create = @party && (@party.user != current_user || @party.edit_key != edit_key)
        unauthorized_update = @summon && @summon.party && (@summon.party.user != current_user || @summon.party.edit_key != edit_key)

        render_unauthorized_response if unauthorized_create || unauthorized_update
      end

      def set
        @summon = GridSummon.where('id = ?', params[:id]).first
      end

      # Specify whitelisted properties that can be modified.
      def summon_params
        params.require(:summon).permit(:id, :party_id, :summon_id, :position, :main, :friend, :uncap_level,
                                       :transcendence_step)
      end
    end
  end
end
