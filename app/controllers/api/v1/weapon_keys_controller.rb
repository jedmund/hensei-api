# frozen_string_literal: true

module Api
  module V1
    class WeaponKeysController < Api::V1::ApiController
      def all
        weapon_keys = WeaponKey.all

        # Filter by series - support both new slug-based and legacy integer-based filtering
        if request.params['series_slug'].present?
          series = WeaponSeries.find_by(slug: request.params['series_slug'])
          weapon_keys = weapon_keys.joins(:weapon_series).where(weapon_series: { id: series.id }) if series
        elsif request.params['series'].present?
          # Legacy integer support (will be deprecated)
          weapon_keys = weapon_keys.where('? = ANY(series)', request.params['series'].to_i)
        end

        # Filter by slot and group
        weapon_keys = weapon_keys.where(slot: request.params['slot'].to_i) if request.params['slot'].present?
        weapon_keys = weapon_keys.where(group: request.params['group'].to_i) if request.params['group'].present?

        render json: WeaponKeyBlueprint.render(weapon_keys)
      end
    end
  end
end
