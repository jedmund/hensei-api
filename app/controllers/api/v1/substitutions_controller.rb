# frozen_string_literal: true

module Api
  module V1
    class SubstitutionsController < ApiController
      include PartyAuthorizationConcern

      before_action :restrict_access
      before_action :set_party
      before_action :authorize_party!
      before_action :set_substitution, only: %i[update destroy]

      def create
        grid_type = substitution_params[:grid_type]
        grid_id = substitution_params[:grid_id]
        item_id = substitution_params[:item_id]
        position = substitution_params[:position] || next_position(grid_type, grid_id)

        grid_item = grid_type.constantize.find(grid_id)
        item_fk = item_foreign_key(grid_type)

        substitute = grid_type.constantize.create!(
          party: @party,
          item_fk => item_id,
          position: grid_item.position,
          uncap_level: 0,
          is_substitute: true
        )

        substitution = Substitution.create!(
          grid_type: grid_type,
          grid_id: grid_id,
          substitute_grid_type: grid_type,
          substitute_grid_id: substitute.id,
          position: position.to_i
        )

        @party.mark_updated!

        render json: SubstitutionBlueprint.render(substitution), status: :created
      end

      def update
        @substitution.update!(position: substitution_params[:position])
        @party.mark_updated!

        render json: SubstitutionBlueprint.render(@substitution)
      end

      def destroy
        substitute = @substitution.substitute_grid
        @substitution.destroy!
        substitute&.destroy!
        @party.mark_updated!

        head :no_content
      end

      private

      def set_party
        party_id = params[:party_id] || params.dig(:substitution, :party_id)
        @party = Party.find(party_id)
      end

      def set_substitution
        @substitution = Substitution.find(params[:id])
      end

      def substitution_params
        params.require(:substitution).permit(
          :grid_type, :grid_id, :item_id, :position, :party_id
        )
      end

      def next_position(grid_type, grid_id)
        Substitution.where(grid_type: grid_type, grid_id: grid_id).maximum(:position).to_i + 1
      end

      def item_foreign_key(grid_type)
        case grid_type
        when 'GridCharacter' then :character_id
        when 'GridWeapon' then :weapon_id
        when 'GridSummon' then :summon_id
        end
      end
    end
  end
end
