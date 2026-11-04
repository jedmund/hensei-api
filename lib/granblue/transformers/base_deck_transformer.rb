# frozen_string_literal: true

module Granblue
  module Transformers
    class BaseDeckTransformer < BaseTransformer
      def transform
        Rails.logger.info '[TRANSFORM] Starting BaseDeckTransformer#transform'
        Rails.logger.info "[TRANSFORM] Data class: #{data.class}"

        # Handle already transformed parameters
        if data.is_a?(ActionController::Parameters) && data.key?(:name)
          Rails.logger.info '[TRANSFORM] Found existing parameters, returning as is'
          return data.to_h.symbolize_keys
        end

        deck, pc = raw_deck
        return {} unless pc

        result = build_deck(deck, pc)
        Rails.logger.info '[TRANSFORM] Completed transformation'
        Rails.logger.debug { "[TRANSFORM] Result: #{result}" }

        result
      end

      private

      # The raw game data's deck and its pc data, or nil when either is missing.
      def raw_deck
        Rails.logger.info '[TRANSFORM] Processing raw game data'
        input_data = data['import'] if data.is_a?(Hash)
        unless input_data
          Rails.logger.error '[TRANSFORM] No import data found'
          return
        end

        Rails.logger.info '[TRANSFORM] Found import data'
        deck = input_data['deck']
        pc = deck['pc'] if deck
        return [deck, pc] if deck && pc

        Rails.logger.error '[TRANSFORM] Missing deck or pc data'
        Rails.logger.error "[TRANSFORM] deck present: #{!deck.nil?}"
        Rails.logger.error "[TRANSFORM] pc present: #{!pc.nil?}"
        nil
      end

      # @param deck [Hash] the raw deck
      # @param player [Hash] the deck's pc data
      def build_deck(deck, player)
        Rails.logger.info '[TRANSFORM] Building deck data structure'
        {
          lang: language,
          name: deck['name'] || 'Untitled',
          class: player.dig('job', 'master', 'name'),
          extra: player['isExtraDeck'] || false,
          subskills: transform_subskills(player['set_action']),
          characters: transform_characters(deck['npc']),
          weapons: transform_weapons(player['weapons']),
          summons: transform_summons(player['summons'], player['quick_user_summon_id']),
          sub_summons: transform_summons(player['sub_summons']),
          friend_summon: player.dig('damage_info', 'summon_name')
        }
      end

      def transform_subskills(set_action)
        Rails.logger.info '[TRANSFORM] Processing subskills'
        unless set_action.is_a?(Array) && !set_action.empty?
          Rails.logger.info '[TRANSFORM] No valid set_action data'
          return []
        end

        skills = set_action[0]
        unless skills.is_a?(Array)
          Rails.logger.info '[TRANSFORM] Invalid skills array'
          return []
        end

        results = skills.filter_map { |skill| skill['name'] if skill.is_a?(Hash) }
        Rails.logger.info "[TRANSFORM] Found #{results.length} subskills"
        results
      end

      def transform_characters(npc_data)
        Rails.logger.info '[TRANSFORM] Processing characters'
        CharacterTransformer.new(npc_data, options).transform
      end

      def transform_weapons(weapons_data)
        Rails.logger.info '[TRANSFORM] Processing weapons'
        WeaponTransformer.new(weapons_data, options).transform
      end

      def transform_summons(summons_data, quick_summon_id = nil)
        Rails.logger.info '[TRANSFORM] Processing summons'
        SummonTransformer.new(summons_data, quick_summon_id, options).transform
      end
    end
  end
end
