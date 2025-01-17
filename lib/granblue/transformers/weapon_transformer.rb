module Granblue
  module Transformers
    class WeaponTransformer < BaseTransformer
      UNCAP_LEVELS = [40, 60, 80, 100, 150, 200].freeze
      TRANSCENDENCE_LEVELS = [210, 220, 230, 240].freeze
      MULTIELEMENT_SERIES = [13, 17, 19].freeze

      def transform
        Rails.logger.info "[TRANSFORM] Starting WeaponTransformer#transform"

        unless data.is_a?(Hash)
          Rails.logger.error "[TRANSFORM] Invalid weapon data structure"
          return []
        end

        weapons = []
        data.each_value do |weapon_data|
          next unless weapon_data['master'] && weapon_data['param']

          master = weapon_data['master']
          param = weapon_data['param']

          Rails.logger.debug "[TRANSFORM] Processing weapon: #{master['name']}"

          weapon = transform_base_attributes(master, param)
          Rails.logger.debug "[TRANSFORM] Base weapon attributes: #{weapon}"

          weapon.merge!(transform_awakening(param))
          Rails.logger.debug "[TRANSFORM] After awakening: #{weapon[:awakening] if weapon[:awakening]}"

          weapon.merge!(transform_ax_skills(param))
          Rails.logger.debug "[TRANSFORM] After AX skills: #{weapon[:ax] if weapon[:ax]}"

          weapon.merge!(transform_weapon_keys(weapon_data))
          Rails.logger.debug "[TRANSFORM] After weapon keys: #{weapon[:keys] if weapon[:keys]}"

          weapons << weapon unless master['id'].nil?
          Rails.logger.info "[TRANSFORM] Successfully processed weapon #{weapon[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{weapons.length} weapons"
        weapons
      end

      private

      def transform_base_attributes(master, param)
        Rails.logger.debug "[TRANSFORM] Processing base attributes for weapon"

        series = master['series_id'].to_i
        weapon = {
          name: master['name'],
          id: master['id']
        }

        # Handle multi-element weapons
        if MULTIELEMENT_SERIES.include?(series)
          element = master['attribute'].to_i - 1
          weapon[:attr] = element
          weapon[:id] = (master['id'].to_i - (element * 100)).to_s
          Rails.logger.debug "[TRANSFORM] Multi-element weapon adjustments made"
        end

        # Calculate uncap level
        level = param['level'].to_i
        uncap = calculate_uncap_level(level)
        weapon[:uncap] = uncap
        Rails.logger.debug "[TRANSFORM] Calculated uncap level: #{uncap}"

        # Add transcendence if applicable
        if uncap > 5
          trans = calculate_transcendence_level(level)
          weapon[:transcend] = trans
          Rails.logger.debug "[TRANSFORM] Added transcendence level: #{trans}"
        end

        weapon
      end

      def transform_awakening(param)
        return {} unless param['arousal']&.[]('is_arousal_weapon')

        Rails.logger.debug "[TRANSFORM] Processing weapon awakening"
        {
          awakening: {
            type: param['arousal']['form_name'],
            lvl: param['arousal']['level']
          }
        }
      end

      def transform_ax_skills(param)
        augments = param['augment_skill_info']
        return {} unless augments&.first&.any?

        Rails.logger.debug "[TRANSFORM] Processing AX skills"
        ax = []
        augments.first.each_value do |augment|
          ax_skill = {
            id: augment['skill_id'].to_s,
            val: augment['show_value']
          }
          ax << ax_skill
          Rails.logger.debug "[TRANSFORM] Added AX skill: #{ax_skill}"
        end

        { ax: ax }
      end

      def transform_weapon_keys(weapon_data)
        Rails.logger.debug "[TRANSFORM] Processing weapon keys"
        keys = []

        # Add weapon keys if they exist
        ['skill1', 'skill2', 'skill3'].each do |skill_key|
          if weapon_data[skill_key]&.[]('id')
            keys << weapon_data[skill_key]['id']
            Rails.logger.debug "[TRANSFORM] Added weapon key: #{weapon_data[skill_key]['id']}"
          end
        end

        keys.any? ? { keys: keys } : {}
      end

      def calculate_uncap_level(level)
        return 0 unless level
        UNCAP_LEVELS.count { |cutoff| level.to_i > cutoff }
      end

      def calculate_transcendence_level(level)
        return 1 unless level
        1 + TRANSCENDENCE_LEVELS.count { |cutoff| level.to_i > cutoff }
      end
    end
  end
end
