# frozen_string_literal: true

module Granblue
  module Transformers
    class SummonTransformer < BaseTransformer
      TRANSCENDENCE_LEVELS = [210, 220, 230, 240].freeze

      def initialize(data, quick_summon_id = nil, options = {})
        super(data, options)
        @quick_summon_id = quick_summon_id
        Rails.logger.info "[TRANSFORM] Initializing SummonTransformer with quick_summon_id: #{quick_summon_id}"
      end

      def transform
        Rails.logger.info "[TRANSFORM] Starting SummonTransformer#transform"

        unless data.is_a?(Hash)
          Rails.logger.error "[TRANSFORM] Invalid summon data structure"
          Rails.logger.error "[TRANSFORM] Data class: #{data.class}"
          return []
        end

        summons = []
        data.each_value do |summon_data|
          Rails.logger.debug "[TRANSFORM] Processing summon: #{summon_data['master']['name'] if summon_data['master']}"

          master, param = get_master_param(summon_data)
          unless master && param
            Rails.logger.debug "[TRANSFORM] Skipping summon - missing master or param data"
            next
          end

          summon = {
            name: master['name'],
            id: master['id'],
            uncap: param['evolution'].to_i
          }

          Rails.logger.debug "[TRANSFORM] Base summon data: #{summon}"

          # Add transcendence if applicable
          if summon[:uncap] > 5
            level = param['level'].to_i
            trans = calculate_transcendence_level(level)
            summon[:transcend] = trans
            Rails.logger.debug "[TRANSFORM] Added transcendence level: #{trans}"
          end

          # Mark quick summon if applicable
          if @quick_summon_id && param['id'].to_s == @quick_summon_id.to_s
            summon[:qs] = true
            Rails.logger.debug "[TRANSFORM] Marked as quick summon"
          end

          summons << summon
          Rails.logger.info "[TRANSFORM] Successfully processed summon #{summon[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{summons.length} summons"
        summons
      end

      private

      def calculate_transcendence_level(level)
        return 1 unless level
        level = 1 + TRANSCENDENCE_LEVELS.count { |cutoff| level > cutoff }
        Rails.logger.debug "[TRANSFORM] Calculated transcendence level: #{level}"
        level
      end
    end
  end
end
