# frozen_string_literal: true

module Granblue
  module Parsers
    # Shared read accessor for a character's wiki template params and game-data
    # action blobs. Both StatusCatalogBuilder and CharacterSkillParser navigate the
    # same `wiki_raw` template params and `game_raw_en/jp` ability structures, so
    # that logic lives here once.
    class CharacterWikiData
      STATUS_TEMPLATE = /\{\{status\|([^}]+)\}\}/i

      def initialize(character)
        @character = character
        @params = extract_template_params(character.wiki_raw.to_s)
        @game_en = character.game_raw_en || {}
        @game_jp = character.game_raw_jp || {}
      end

      attr_reader :params, :game_en, :game_jp

      # Resolves the game-data action hash for a skill key (e.g. "a1", "a3a",
      # "ougi", "ougi2", "sa", "sa2") in the requested language.
      def game_action(key, lang: :en)
        data = lang == :jp ? game_jp : game_en

        action = case key
                 when /\Aa(\d+)\z/
                   collection_entry(data['ability'], Regexp.last_match(1))
                 when /\Aa(\d+)[a-z]\z/
                   nested_action(collection_entry(data['ability'], Regexp.last_match(1)), key)
                 when 'ougi', 'ougi1'
                   data['special_skill']
                 when /\Aougi(\d+)\z/
                   Regexp.last_match(1) == '2' ? data['power_up_special_skill'] : nil
                 when /\Asa(\d*)\z/
                   position = Regexp.last_match(1).presence || '1'
                   collection_entry(data['support_ability'], position) ||
                   collection_entry(data['backmember_ability'], position) ||
                   collection_entry(data['appear_ability'], position)
                 end

        action.is_a?(Hash) ? action : nil
      end

      def csv(value)
        value.to_s.split(',').map(&:strip).reject(&:blank?)
      end

      private

      attr_reader :character

      def collection_entry(collection, position)
        case collection
        when Hash then collection[position.to_s]
        when Array then collection[position.to_i - 1]
        end
      end

      # Sub-skills (Caim's Tricks, etc.) live in a nested action list and are
      # matched to the wiki key by display name.
      def nested_action(action, key)
        actions = action&.dig('display_action_ability_info', 'action_ability')
        Array(actions).find { |nested| nested['name_en'].to_s == params["#{key}_name"].to_s.strip }
      end

      def extract_template_params(wikitext)
        data = {}

        # Strip HTML comments first: commented-out text can mention section
        # names like "Gameplay Notes" (e.g. in the |gender= field) and would
        # otherwise terminate parsing before the ability params, or leak into
        # values.
        wikitext.gsub(/<!--.*?-->/m, '').each_line do |line|
          break if line.include?('Gameplay Notes')
          next unless line.start_with?('|')

          key, value = line[1..].split('=', 2).map { |part| part&.strip }
          next if key.blank?

          data[key] = value.to_s
        end

        data
      end
    end
  end
end
