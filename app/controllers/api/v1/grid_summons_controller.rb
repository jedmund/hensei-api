# frozen_string_literal: true

module Api
  module V1
    class GridSummonsController < Api::V1::ApiController
      attr_reader :party, :incoming_summon

      before_action :set, only: %w[update update_uncap_level update_quick_summon]
      before_action :find_party, only: :create
      before_action :find_incoming_summon, only: :create
      before_action :authorize, only: %i[create update update_uncap_level update_quick_summon destroy]

      def create
        # Create the GridSummon with the desired parameters
        summon = GridSummon.new
        summon.attributes = summon_params.merge(party_id: party.id, summon_id: incoming_summon.id)
        summon.uncap_level = max_uncap_level(summon) if summon.uncap_level.nil?

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

      def update_uncap_level
        summon = @summon.summon
        max_uncap_level = max_uncap_level(summon)

        greater_than_max_uncap = summon_params[:uncap_level].to_i > max_uncap_level
        can_be_transcended = summon.xlb && summon_params[:transcendence_step] && summon_params[:transcendence_step]&.to_i&.positive?

        uncap_level = if greater_than_max_uncap || can_be_transcended
                        max_uncap_level
                      else
                        summon_params[:uncap_level]
                      end

        transcendence_step = if summon.xlb && summon_params[:transcendence_step]
                               summon_params[:transcendence_step]
                             else
                               0
                             end

        @summon.update!(
          uncap_level: uncap_level,
          transcendence_step: transcendence_step
        )

        return unless @summon.persisted?

        render json: GridSummonBlueprint.render(@summon, view: :nested, root: :grid_summon)
      end

      def update_quick_summon
        return if [4, 5, 6].include?(@summon.position)

        quick_summons = @summon.party.summons.select(&:quick_summon)

        quick_summons.each do |summon|
          summon.update!(quick_summon: false)
        end

        @summon.update!(quick_summon: summon_params[:quick_summon])
        return unless @summon.persisted?

        quick_summons -= [@summon]
        summons = [@summon] + quick_summons

        render json: GridSummonBlueprint.render(summons, view: :nested, root: :summons)
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
        return unless conflict_summon.summon.id == incoming_summon.id

        old_position = conflict_summon.position
        conflict_summon.position = summon_params[:position]

        return unless conflict_summon.save

        output = render_grid_summon_view(conflict_summon, old_position)
        render json: output
      end

      def destroy
        summon = GridSummon.find_by('id = ?', params[:id])
        render_unauthorized_response if summon.party.user != current_user
        return render json: GridSummonBlueprint.render(summon, view: :destroyed) if summon.destroy
      end

      private

      def max_uncap_level(summon)
        object = summon.summon
        if object.flb && !object.ulb && !object.xlb
          4
        elsif object.ulb && !object.xlb
          5
        elsif object.xlb
          6
        else
          3
        end
      end

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
        @summon = GridSummon.find_by('id = ?', summon_params[:id])
      end

      # Specify whitelisted properties that can be modified.
      def summon_params
        params.require(:summon).permit(:id, :party_id, :summon_id, :position, :main, :friend,
                                       :quick_summon, :uncap_level, :transcendence_step)
      end
    end
  end
end
