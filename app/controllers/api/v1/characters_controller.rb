# frozen_string_literal: true

module Api
  module V1
    class CharactersController < Api::V1::ApiController
      before_action :set

      def show
        render json: CharacterBlueprint.render(@character)
      end

      private

      def set
        @character = Character.where(granblue_id: params[:id]).first
      end
    end
  end
end
