# frozen_string_literal: true

module Api
  module V1
    ##
    # The Wonders catalogue: categories, and every Wonder with its effects,
    # per-level bonuses and evolution caps. Public, static between data
    # migrations, and cacheable.
    class WondersController < Api::V1::ApiController
      CACHE_TTL = 1.hour

      # GET /wonders
      def index
        expires_in CACHE_TTL, public: true

        wonders = Wonder.ordered.includes({ wonder_effect_links: :wonder_effect }, :level_bonuses, :evolution_caps)
        render json: {
          categories: WonderCategoryBlueprint.render_as_hash(WonderCategory.ordered),
          wonders: WonderBlueprint.render_as_hash(wonders)
        }
      end
    end
  end
end
