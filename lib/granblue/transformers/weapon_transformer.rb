module Granblue
  module Transformers
    # Transforms raw game weapon data into standardized format for database import.
    # Handles weapon stats, uncap levels, transcendence, awakening, AX skills, and weapon keys.
    #
    # @example Transforming weapon data
    #   data = {
    #     "master" => { "name" => "Luminiera Sword Omega", "id" => "1040007100", "series_id" => 1 },
    #     "param" => { "level" => 150, "arousal" => { "is_arousal_weapon" => true } }
    #   }
    #   transformer = WeaponTransformer.new(data)
    #   result = transformer.transform
    #   # => [{ name: "Luminiera Sword Omega", id: "1040007100", uncap: 4, ... }]
    #
    # @note Expects data with "master" and "param" nested objects for each weapon
    # @note Special handling for multi-element weapons from specific series
    #
    # @see BaseTransformer For base transformation functionality
    class WeaponTransformer < BaseTransformer
      # @return [Array<Integer>] Level thresholds for determining uncap level
      UNCAP_LEVELS = [40, 60, 80, 100, 150, 200].freeze

      # @return [Array<Integer>] Level thresholds for determining transcendence level
      TRANSCENDENCE_LEVELS = [210, 220, 230, 240].freeze

      # @return [Array<Integer>] Weapon series IDs that can have multiple elements
      MULTIELEMENT_SERIES = [13, 17, 19].freeze

      # Transform raw weapon data into standardized format
      # @return [Array<Hash>] Array of transformed weapon data
      def transform
        # Log start of transformation process
        Rails.logger.info "[TRANSFORM] Starting WeaponTransformer#transform"

        # Validate that the input data is a Hash
        unless data.is_a?(Hash)
          Rails.logger.error "[TRANSFORM] Invalid weapon data structure"
          return []
        end

        weapons = []
        # Iterate through each weapon entry in the data
        data.each_value do |weapon_data|
          # Skip entries missing required master/param data
          next unless weapon_data['master'] && weapon_data['param']

          master = weapon_data['master']
          param = weapon_data['param']

          Rails.logger.debug "[TRANSFORM] Processing weapon: #{master['name']}"

          # Transform base weapon attributes (ID, name, uncap level, etc)
          weapon = transform_base_attributes(master, param)
          Rails.logger.debug "[TRANSFORM] Base weapon attributes: #{weapon}"

          # Add awakening data if present
          weapon.merge!(transform_awakening(param))
          Rails.logger.debug "[TRANSFORM] After awakening: #{weapon[:awakening] if weapon[:awakening]}"

          # Add AX skills if present
          weapon.merge!(transform_ax_skills(param))
          Rails.logger.debug "[TRANSFORM] After AX skills: #{weapon[:ax] if weapon[:ax]}"

          # Add weapon keys if present
          weapon.merge!(transform_weapon_keys(weapon_data))
          Rails.logger.debug "[TRANSFORM] After weapon keys: #{weapon[:keys] if weapon[:keys]}"

          # Only add weapons with valid IDs
          weapons << weapon unless master['id'].nil?
          Rails.logger.info "[TRANSFORM] Successfully processed weapon #{weapon[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{weapons.length} weapons"
        weapons
      end

      private

      # Transforms the core weapon attributes from master and param data
      # @param master [Hash] Master data containing basic weapon information
      # @param param [Hash] Parameter data containing weapon's current state
      # @return [Hash] Base weapon attributes including ID, name, uncap level, etc
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

      # Transforms weapon awakening data if present
      # @param param [Hash] Parameter data containing awakening information
      # @return [Hash] Awakening type and level if weapon is awakened
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

      # Transforms AX skill data if present
      # @param param [Hash] Parameter data containing AX skill information
      # @return [Hash] Array of AX skills with IDs and values
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

      # Transforms weapon key data if present
      # @param weapon_data [Hash] Full weapon data containing key information
      # @return [Hash] Array of weapon key IDs
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

      # Calculates uncap level based on weapon level
      # @param level [Integer, nil] Current weapon level
      # @return [Integer] Calculated uncap level
      def calculate_uncap_level(level)
        return 0 unless level
        UNCAP_LEVELS.count { |cutoff| level.to_i > cutoff }
      end

      # Calculates transcendence level based on weapon level
      # @param level [Integer, nil] Current weapon level
      # @return [Integer] Calculated transcendence level
      def calculate_transcendence_level(level)
        return 1 unless level
        1 + TRANSCENDENCE_LEVELS.count { |cutoff| level.to_i > cutoff }
      end
    end
  end
end
