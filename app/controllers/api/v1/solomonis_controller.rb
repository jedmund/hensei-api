# frozen_string_literal: true

module Api
  module V1
    ##
    # Evoking Solomonis catalogues: route Evokers, Arcarum Blessings (with the
    # loadout cost limit) and guidebook effects. Public, static between data
    # migrations, and cacheable.
    class SolomonisController < Api::V1::ApiController
      CACHE_TTL = 1.hour

      before_action :cache_publicly

      # GET /solomonis/route_evokers
      def route_evokers
        # Grouped by zone: the zone slugs sort in release order (allotropic, paracyclic)
        evokers = Character.solomonis_route_evokers
                           .includes(:solomonis_zone)
                           .joins(:solomonis_zone)
                           .order('raids.slug', :granblue_id)
        render json: { route_evokers: SolomonisRouteEvokerBlueprint.render_as_hash(evokers, view: :catalogue) }
      end

      # GET /solomonis/blessings
      def blessings
        blessings = ArcarumBlessing.ordered.includes(:levels)
        render json: {
          cost_limit: ArcarumBlessing::COST_LIMIT,
          blessings: ArcarumBlessingBlueprint.render_as_hash(blessings, view: :catalogue)
        }
      end

      # GET /solomonis/guide_effects
      def guide_effects
        render json: { guide_effects: SolomonisGuideEffectBlueprint.render_as_hash(SolomonisGuideEffect.ordered) }
      end

      private

      def cache_publicly
        expires_in CACHE_TTL, public: true
      end
    end
  end
end
