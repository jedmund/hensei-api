# frozen_string_literal: true

module Granblue
  module Parsers
    class BaseParser
      def initialize(entity, debug: false, use_local: false)
        @entity = entity
        @wiki = Granblue::Parsers::Wiki.new
        @debug = debug || false
        @use_local = use_local || false
      end

      def fetch(save: false)
        # Use local data if available and requested
        if @use_local && @entity.wiki_raw.present?
          wikitext = @entity.wiki_raw
          return handle_fetch_success(wikitext, save)
        end

        # Otherwise fetch from wiki
        response = fetch_wiki_info
        return false if response.nil?

        redirect = handle_redirected_string(response)
        return fetch(save: save) unless redirect.nil?

        handle_fetch_success(response, save)
      end

      protected

      def parse_string(string)
        lines = string.split("\n")
        data = {}
        stop_loop = false
        template_data = {}

        lines.each do |line|
          next if stop_loop

          if line.include?('Gameplay Notes')
            stop_loop = true
            next
          end

          # Template handling
          if line.start_with?('{{')
            template_data = extract_template_info(line)
            data[:template] = template_data[:name] if template_data[:name]
            next
          end

          # Standard key-value pairs
          next unless line[0] == '|' && line.size > 2

          key, value = line[1..].split('=', 2).map(&:strip)
          data[key] = value if value && !value.match?(/\A\{\{\{.*\|\}\}\}\z/)
        end

        data
      end

      def extract_template_info(line)
        result = { name: nil }

        substr = line[2..].strip! || line[2..]

        # Skip disallowed templates
        disallowed = %w[#vardefine #lsth About]
        return result if substr.start_with?(*disallowed)

        # Extract entity type template name
        entity_types = %w[Character Weapon Summon]
        entity_types.each do |type|
          next unless substr.start_with?(type)

          substr = substr.split('|').first
          result[:name] = substr if substr != type
          break
        end

        result
      end

      def handle_redirected_string(response)
        redirect = extract_redirected_string(response)
        return unless redirect

        @entity.wiki_en = redirect
        return unless @entity.save!

        ap "Saved new wiki_en value: #{redirect}" if @debug
        redirect
      end

      def extract_redirected_string(string)
        string.match(/#REDIRECT \[\[(.*?)\]\]/)&.captures&.first
      end

      def handle_fetch_success(response, save)
        @entity.wiki_raw = response
        @entity.save!

        ap "Successfully fetched info for #{@entity.wiki_en}" if @debug

        extracted = parse_string(response)

        # Handle template
        if extracted[:template]
          template = @wiki.fetch("Template:#{extracted[:template]}")
          extracted.merge!(parse_string(template))
        end

        info = parse(extracted)
        persist(info) if save
        true
      end

      def fetch_wiki_info
        @wiki.fetch(@entity.wiki_en)
      rescue WikiError => e
        ap "Error fetching #{e.page}: #{e.message}" if @debug
        nil
      end

      # Must be implemented by subclasses
      def parse(hash)
        raise NotImplementedError
      end

      def persist(info)
        raise NotImplementedError
      end

      def parse_date(date_str)
        Date.parse(date_str) unless date_str.blank?
      end
    end
  end
end
