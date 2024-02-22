# frozen_string_literal: true

module Api
  module V1
    class RaidsController < Api::V1::ApiController
      def all
        render json: RaidBlueprint.render(Raid.all, view: :full)
      end

      def show
        raid = Raid.find_by(slug: params[:id])
        render json: RaidBlueprint.render(Raid.find_by(slug: params[:id]), view: :full) if raid
      end

      def groups
        render json: RaidGroupBlueprint.render(RaidGroup.all, view: :full)
      end
    end
  end
end
