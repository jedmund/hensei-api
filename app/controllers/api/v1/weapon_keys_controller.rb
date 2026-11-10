# frozen_string_literal: true

module Api
  module V1
    class WeaponKeysController < Api::V1::ApiController
      before_action :ensure_editor_role, only: %i[update]

      # PATCH /weapon_keys/:id
      def update
        key = WeaponKey.find(params.expect(:id))
        key.update!(params.expect(weapon_key: %i[name_en name_jp]))
        render json: WeaponKeyBlueprint.render(key)
      end

      def all
        weapon_keys = filter_by_series(WeaponKey.preload(:weapon_series), request.params)

        # Filter by slot and group
        weapon_keys = weapon_keys.where(slot: request.params['slot'].to_i) if request.params['slot'].present?
        weapon_keys = weapon_keys.where(group: request.params['group'].to_i) if request.params['group'].present?

        render json: WeaponKeyBlueprint.render(weapon_keys)
      end

      # Returns a mapping of game skill IDs to weapon key slugs.
      # Used by the extension to display weapon key icons without needing the full DB.
      def skill_map
        key_mapping = Processors::WeaponProcessor::KEY_MAPPING
        weapon_keys = WeaponKey.all.index_by(&:granblue_id)

        result = {}
        key_mapping.each do |category_id, skill_ids|
          weapon_key = weapon_keys[category_id.to_i]
          next unless weapon_key

          Array(skill_ids).each do |skill_id|
            result[skill_id] = weapon_key.slug
          end
        end

        render json: result
      end

      private

      # By series slug, else by the legacy integer series (will be
      # deprecated). An unknown slug filters nothing.
      def filter_by_series(weapon_keys, query)
        if query['series_slug'].present?
          series = WeaponSeries.find_by(slug: query['series_slug'])
          series ? weapon_keys.joins(:weapon_series).where(weapon_series: { id: series.id }) : weapon_keys
        elsif query['series'].present?
          weapon_keys.where('? = ANY(series)', query['series'].to_i)
        else
          weapon_keys
        end
      end
    end
  end
end
