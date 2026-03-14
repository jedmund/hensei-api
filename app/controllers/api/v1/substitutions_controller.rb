# frozen_string_literal: true

module Api
  module V1
    class SubstitutionsController < Api::V1::ApiController
      before_action :find_primary_grid_item, only: :create
      before_action :find_substitution, only: %i[update destroy]
      before_action :find_party
      before_action :authorize_party_edit!

      def create
        substitute_grid_item = build_substitute_grid_item
        unless substitute_grid_item.save
          return render_validation_error_response(substitute_grid_item)
        end

        substitution = Substitution.new(
          grid_type: substitution_params[:grid_type],
          grid_id: @primary_grid_item.id,
          substitute_grid_type: substitution_params[:grid_type],
          substitute_grid_id: substitute_grid_item.id,
          position: substitution_params[:position]
        )

        if substitution.save
          render json: SubstitutionBlueprint.render(substitution, root: :substitution), status: :created
        else
          substitute_grid_item.destroy
          render_validation_error_response(substitution)
        end
      end

      def update
        if @substitution.update(position: substitution_params[:position])
          render json: SubstitutionBlueprint.render(@substitution, root: :substitution)
        else
          render_validation_error_response(@substitution)
        end
      end

      def destroy
        substitute = @substitution.substitute_grid
        @substitution.destroy
        substitute&.destroy
        head :no_content
      end

      private

      def build_substitute_grid_item
        case substitution_params[:grid_type]
        when 'GridCharacter'
          character = Character.find_by(id: substitution_params[:character_id])
          return render_not_found_response('character') unless character

          GridCharacter.new(
            party_id: @party.id,
            character_id: character.id,
            position: 0,
            uncap_level: default_character_uncap(character),
            transcendence_step: 0,
            is_substitute: true
          )
        when 'GridWeapon'
          weapon = Weapon.find_by(id: substitution_params[:weapon_id])
          return render_not_found_response('weapon') unless weapon

          GridWeapon.new(
            party_id: @party.id,
            weapon_id: weapon.id,
            position: 0,
            uncap_level: default_weapon_uncap(weapon),
            transcendence_step: 0,
            is_substitute: true
          )
        when 'GridSummon'
          summon = Summon.find_by(id: substitution_params[:summon_id])
          return render_not_found_response('summon') unless summon

          GridSummon.new(
            party_id: @party.id,
            summon_id: summon.id,
            position: 0,
            uncap_level: default_summon_uncap(summon),
            transcendence_step: 0,
            is_substitute: true
          )
        else
          render json: { error: 'Invalid grid_type' }, status: :unprocessable_entity
        end
      end

      def default_character_uncap(character)
        if character.respond_to?(:special) && character.special
          character.ulb ? 5 : (character.flb ? 4 : 3)
        else
          character.ulb ? 6 : (character.flb ? 5 : 4)
        end
      end

      def default_weapon_uncap(weapon)
        if weapon.transcendence then 6
        elsif weapon.ulb then 5
        elsif weapon.flb then 4
        else 3
        end
      end

      def default_summon_uncap(summon)
        if summon.transcendence then 6
        elsif summon.ulb then 5
        elsif summon.flb then 4
        else 3
        end
      end

      def find_primary_grid_item
        grid_type = substitution_params[:grid_type]
        grid_id = substitution_params[:grid_id]

        unless Substitution::GRID_TYPES.include?(grid_type)
          return render json: { error: 'Invalid grid_type' }, status: :unprocessable_entity
        end

        @primary_grid_item = grid_type.constantize.find_by(id: grid_id)
        render_not_found_response('grid_item') unless @primary_grid_item
      end

      def find_substitution
        @substitution = Substitution.find_by(id: params[:id])
        render_not_found_response('substitution') unless @substitution
      end

      def find_party
        @party = if @primary_grid_item
                   @primary_grid_item.party
                 elsif @substitution
                   @substitution.grid.party
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
        params.require(:substitution).permit(
          :grid_type, :grid_id, :position,
          :character_id, :weapon_id, :summon_id
        )
      end
    end
  end
end
