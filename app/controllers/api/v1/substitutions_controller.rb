# frozen_string_literal: true

module Api
  module V1
    class SubstitutionsController < Api::V1::ApiController
      before_action :find_substitution, only: %i[update destroy]
      before_action :find_primary_grid_item, only: :create
      before_action :find_party
      before_action :authorize_party_edit!

      def create
        grid_type = substitution_params[:grid_type]
        item_id = substitution_params[:item_id]
        position = substitution_params[:position]

        # Find the canonical item
        item_class = item_class_for(grid_type)
        item = item_class&.find_by(id: item_id)
        return render_not_found_response(item_class&.name&.underscore || 'item') unless item

        # Create the substitute grid item
        grid_class = grid_type.constantize
        substitute = grid_class.create!(
          party: @party,
          item_fk_for(grid_type) => item_id,
          is_substitute: true,
          position: 0,
          uncap_level: 0
        )

        # Create the substitution join record
        substitution = Substitution.create!(
          grid_type: grid_type,
          grid_id: @primary_grid_item.id,
          substitute_grid_type: grid_type,
          substitute_grid_id: substitute.id,
          position: position.to_i
        )

        render json: SubstitutionBlueprint.render(substitution, root: :substitution),
               status: :created
      end

      def update
        @substitution.update!(position: substitution_params[:position])
        render json: SubstitutionBlueprint.render(@substitution, root: :substitution)
      end

      def destroy
        substitute_grid_item = @substitution.substitute_grid
        @substitution.destroy!
        substitute_grid_item&.destroy!
        head :no_content
      end

      private

      def find_substitution
        @substitution = Substitution.find_by(id: params[:id])
        render_not_found_response('substitution') unless @substitution
      end

      def find_primary_grid_item
        grid_type = substitution_params[:grid_type]
        grid_id = substitution_params[:grid_id]

        return render_not_found_response('grid_item') unless Substitution::GRID_TYPES.include?(grid_type)

        @primary_grid_item = grid_type.constantize.find_by(id: grid_id)
        render_not_found_response('grid_item') unless @primary_grid_item
      end

      def find_party
        @party = if @primary_grid_item
                   @primary_grid_item.party
                 elsif @substitution
                   @substitution.grid&.party
                 end
        render_not_found_response('party') unless @party
      end

      def authorize_party_edit!
        if @party.user.present?
          return if current_user.present? && @party.user == current_user

          render_unauthorized_response
        else
          provided_edit_key = edit_key.to_s.strip.force_encoding('UTF-8')
          party_edit_key = @party.edit_key.to_s.strip.force_encoding('UTF-8')
          return if provided_edit_key.present? &&
                    provided_edit_key.bytesize == party_edit_key.bytesize &&
                    ActiveSupport::SecurityUtils.secure_compare(provided_edit_key, party_edit_key)

          render_unauthorized_response
        end
      end

      def substitution_params
        params.require(:substitution).permit(:grid_type, :grid_id, :item_id, :position)
      end

      def item_class_for(grid_type)
        case grid_type
        when 'GridCharacter' then Character
        when 'GridWeapon' then Weapon
        when 'GridSummon' then Summon
        end
      end

      def item_fk_for(grid_type)
        case grid_type
        when 'GridCharacter' then :character_id
        when 'GridWeapon' then :weapon_id
        when 'GridSummon' then :summon_id
        end
      end
    end
  end
end
