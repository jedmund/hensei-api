# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Stateless helpers that turn raw wiki-template field text into structured
      # values or cleaned display strings. Pure functions — no character or DB state.
      module FieldParser
        # Template/wikilink delimiters that suppress top-level "|" splitting.
        MARKUP_OPENERS = ['{{', '[['].freeze
        MARKUP_CLOSERS = ['}}', ']]'].freeze

        module_function

        def parse_info_des(value)
          text = value.to_s
          inner = text.sub(/\A\{\{InfoDes\|/i, '').delete_suffix('}}')
          params = split_top_level(inner).each_with_object({}) do |part, result|
            key, param_value = part.split('=', 2)
            result[key.to_s.strip] = param_value if key.present? && param_value
          end

          descriptions = [params['des']]
          params.keys.grep(/\Ades\d+\z/).sort_by { |key| key[/\d+/].to_i }.each do |key|
            descriptions << params[key]
          end

          { descriptions: descriptions.map { |description| clean_description(description) } }
        end

        def parse_cooldown(value)
          text = value.to_s
          {
            base: text[/cooldown=(\d+)/, 1]&.to_i,
            enhanced: text.scan(/cooldown\d+=(\d+)/).flatten.map(&:to_i),
            initial: text[/ReadyIn\|(\d+)/, 1]&.to_i
          }
        end

        def parse_duration_value(value)
          text = value.to_s
          if (match = text.match(/InfoDur\|type=([ts])\|duration=([\d.]+)/))
            { value: match[2].to_i, unit: match[1] == 's' ? 'seconds' : 'turns' }
          elsif text.strip == '-'
            { value: nil, unit: 'none' }
          else
            { value: nil, unit: nil }
          end
        end

        def parse_ob_levels(value)
          text = value.to_s
          {
            obtained: text[/obtained=(\d+)/, 1]&.to_i,
            enhanced: text.scan(/enhanced\d*=(\d+)/).flatten.map(&:to_i)
          }
        end

        def clean_description(value)
          clean_markup(value).presence
        end

        def clean_markup(value)
          value.to_s.strip
               .gsub(%r{<br\s*/?>}i, "\n")
               .gsub(%r{<ref[^>]*/>|<ref[^>]*>.*?</ref>}m, '')
               .gsub(/'{2,}/, '')
               .strip
        end

        # Display form of a description: turns wiki templates into readable text
        # ({{status|Name|…}} → Name, {{tt|shown|tip}} → shown) and drops any other
        # leftover {{…}} markup. Effects are parsed from the raw text, not this.
        def display_description(text)
          return if text.blank?

          result = text.gsub(/\[\[(?:[^\]|]*\|)?([^\]]+)\]\]/, '\\1') # [[Page|Text]] / [[Page]] -> Text/Page
          # Collapse {{status|Name|…}} / {{tt|Display|…}} to their first arg,
          # repeating so nested templates unwind innermost-first.
          loop do
            collapsed = result.gsub(/\{\{(?:status|tt)\|([^|{}]+)[^{}]*\}\}/i, '\\1')
            break if collapsed == result

            result = collapsed
          end

          result.gsub(/\{\{[^{}]*\}\}/, '') # drop any remaining flat template
                .gsub(/[{}]{2,}/, '')       # orphaned braces from unbalanced nesting
                .gsub(/[^\S\n]{2,}/, ' ')
                .strip
                .presence
        end

        def clean_trigger_value(text)
          clean_markup(text.to_s)
            .gsub(/\{\{tt\|([^|}]+)\|[^}]*\}\}/i, '\\1')
            .delete('()')
            .strip
            .presence
        end

        def first_icon(value)
          value.to_s.split(',').first&.strip.presence
        end

        def split_name(name)
          name.to_s.split('/').map { |part| clean_markup(part) }
        end

        def jp_name_for(game_action)
          return if game_action.blank?
          return if game_action['name_en'].present? && game_action['name'] == game_action['name_en']

          game_action['name']
        end

        def clean_status_name(name)
          name.to_s.strip
        end

        def split_top_level(text)
          parts = []
          buffer = +''
          depth = 0
          index = 0

          while index < text.length
            pair = text[index, 2]
            if MARKUP_OPENERS.include?(pair)
              depth += 1
              buffer << pair
              index += 2
            elsif MARKUP_CLOSERS.include?(pair)
              depth -= 1 if depth.positive?
              buffer << pair
              index += 2
            elsif text[index] == '|' && depth.zero?
              parts << buffer
              buffer = +''
              index += 1
            else
              buffer << text[index]
              index += 1
            end
          end

          parts << buffer
          parts
        end
      end
    end
  end
end
