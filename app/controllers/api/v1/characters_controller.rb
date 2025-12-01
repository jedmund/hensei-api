# frozen_string_literal: true

module Api
  module V1
    class CharactersController < Api::V1::ApiController
      include IdResolvable

      before_action :set

      def show
        render json: CharacterBlueprint.render(@character, view: :full)
      end

      def related
        return render json: [] unless @character.character_id

        related = Character.where(character_id: @character.character_id)
                           .where.not(id: @character.id)
        render json: CharacterBlueprint.render(related)
      end

      private

      def set
        @character = find_by_any_id(Character, params[:id])
        render_not_found_response('character') unless @character
      end
    end
  end
end
