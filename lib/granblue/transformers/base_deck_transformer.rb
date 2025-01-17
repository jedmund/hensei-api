# frozen_string_literal: true

module Granblue
  module Transformers
    class BaseDeckTransformer < BaseTransformer
      def transform
        Rails.logger.info "[TRANSFORM] Starting BaseDeckTransformer#transform"
        Rails.logger.info "[TRANSFORM] Data class: #{data.class}"

        # Handle already transformed parameters
        if data.is_a?(ActionController::Parameters) && data.key?(:name)
          Rails.logger.info "[TRANSFORM] Found existing parameters, returning as is"
          return data.to_h.symbolize_keys
        end

        # Handle raw game data
        Rails.logger.info "[TRANSFORM] Processing raw game data"
        input_data = data['import'] if data.is_a?(Hash)
        unless input_data
          Rails.logger.error "[TRANSFORM] No import data found"
          return {}
        end

        Rails.logger.info "[TRANSFORM] Found import data"
        deck = input_data['deck']
        pc = deck['pc'] if deck

        unless deck && pc
          Rails.logger.error "[TRANSFORM] Missing deck or pc data"
          Rails.logger.error "[TRANSFORM] deck present: #{!!deck}"
          Rails.logger.error "[TRANSFORM] pc present: #{!!pc}"
          return {}
        end

        Rails.logger.info "[TRANSFORM] Building deck data structure"
        result = {
          lang: language,
          name: deck['name'] || 'Untitled',
          class: pc.dig('job', 'master', 'name'),
          extra: pc['isExtraDeck'] || false,
          subskills: transform_subskills(pc['set_action']),
          characters: transform_characters(deck['npc']),
          weapons: transform_weapons(pc['weapons']),
          summons: transform_summons(pc['summons'], pc['quick_user_summon_id']),
          sub_summons: transform_summons(pc['sub_summons']),
          friend_summon: pc.dig('damage_info', 'summon_name')
        }

        Rails.logger.info "[TRANSFORM] Completed transformation"
        Rails.logger.debug "[TRANSFORM] Result: #{result}"

        result
      end

      private

      def transform_subskills(set_action)
        Rails.logger.info "[TRANSFORM] Processing subskills"
        unless set_action.is_a?(Array) && !set_action.empty?
          Rails.logger.info "[TRANSFORM] No valid set_action data"
          return []
        end

        skills = set_action[0]
        unless skills.is_a?(Array)
          Rails.logger.info "[TRANSFORM] Invalid skills array"
          return []
        end

        results = skills.map { |skill| skill['name'] if skill.is_a?(Hash) }.compact
        Rails.logger.info "[TRANSFORM] Found #{results.length} subskills"
        results
      end

      def transform_characters(npc_data)
        Rails.logger.info "[TRANSFORM] Processing characters"
        CharacterTransformer.new(npc_data, options).transform
      end

      def transform_weapons(weapons_data)
        Rails.logger.info "[TRANSFORM] Processing weapons"
        WeaponTransformer.new(weapons_data, options).transform
      end

      def transform_summons(summons_data, quick_summon_id = nil)
        Rails.logger.info "[TRANSFORM] Processing summons"
        SummonTransformer.new(summons_data, quick_summon_id, options).transform
      end
    end
  end
end
