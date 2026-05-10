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

        grid_class = grid_class_for(grid_type)
        return render json: { error: "invalid grid_type: #{grid_type}" }, status: :unprocessable_entity unless grid_class

        grid_item = grid_class.where(party: @party).find_by(id: grid_id)
        return render_not_found_response('grid item') unless grid_item

        item_fk = item_foreign_key(grid_type)

        if substitute_already_present?(grid_type, grid_id, item_fk, item_id)
          return render json: { error: 'item is already a substitute for this slot' }, status: :unprocessable_entity
        end

        substitute = grid_class.create!(
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
        @substitution = Substitution.find_by(id: params[:id])
        # Treat cross-party access as not-found to avoid leaking which ids exist.
        render_not_found_response('substitution') if @substitution.nil? || @substitution.grid&.party_id != @party.id
      end

      def substitution_params
        params.require(:substitution).permit(
          :grid_type, :grid_id, :item_id, :position, :party_id
        )
      end

      def next_position(grid_type, grid_id)
        Substitution.where(grid_type: grid_type, grid_id: grid_id).maximum(:position).to_i + 1
      end

      GRID_TYPE_FOREIGN_KEYS = {
        'GridCharacter' => :character_id,
        'GridWeapon' => :weapon_id,
        'GridSummon' => :summon_id
      }.freeze

      def item_foreign_key(grid_type)
        GRID_TYPE_FOREIGN_KEYS[grid_type]
      end

      # Allowlist gate so attacker-supplied grid_type can't load arbitrary classes.
      def grid_class_for(grid_type)
        return nil unless GRID_TYPE_FOREIGN_KEYS.key?(grid_type)

        grid_type.constantize
      end

      # Reject if this item is already a substitute for the same parent slot.
      # Substitutes per slot are bounded (the model caps at 10), so loading them
      # all and comparing in Ruby is fine and avoids polymorphic-join gymnastics.
      def substitute_already_present?(grid_type, grid_id, item_fk, item_id)
        Substitution.where(grid_type: grid_type, grid_id: grid_id)
                    .includes(:substitute_grid)
                    .filter_map(&:substitute_grid)
                    .any? { |sg| sg[item_fk] == item_id }
      end
    end
  end
end
