module Granblue
  module Transformers
    class CharacterTransformer < BaseTransformer
      def transform
        Rails.logger.info "[TRANSFORM] Starting CharacterTransformer#transform"

        unless data.is_a?(Hash)
          Rails.logger.error "[TRANSFORM] Invalid character data structure"
          return []
        end

        characters = []
        data.each_value do |char_data|
          next unless char_data['master'] && char_data['param']

          master = char_data['master']
          param = char_data['param']

          Rails.logger.debug "[TRANSFORM] Processing character: #{master['name']}"

          character = {
            name: master['name'],
            id: master['id'],
            uncap: param['evolution'].to_i
          }

          Rails.logger.debug "[TRANSFORM] Base character data: #{character}"

          # Add perpetuity (rings) if present
          if param['has_npcaugment_constant']
            character[:ringed] = true
            Rails.logger.debug "[TRANSFORM] Character is ringed"
          end

          # Add transcendence if present
          phase = param['phase'].to_i
          if phase && phase.positive?
            character[:transcend] = phase
            Rails.logger.debug "[TRANSFORM] Character has transcendence: #{phase}"
          end

          characters << character unless master['id'].nil?
          Rails.logger.info "[TRANSFORM] Successfully processed character #{character[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{characters.length} characters"
        characters
      end
    end
  end
end
