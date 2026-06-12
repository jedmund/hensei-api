# frozen_string_literal: true

module Granblue
  module Parsers
    # Public façade for parsing a character's wiki/game data into the normalized
    # skill graph. Orchestrates the CharacterSkills::* collaborators: Builder
    # assembles the graph, JpLocalizer fills Japanese text, Reporter builds the
    # diagnostic report, and Persister writes it.
    class CharacterSkillParser
      attr_reader :character

      # status_lookup: an optional preloaded { by_name:, by_id: } index so a batch
      # run resolves the Status catalog once instead of per character.
      def initialize(character, status_lookup: nil)
        @character = character
        @data = CharacterWikiData.new(character)
        @status_lookup = status_lookup
      end

      def parse(persist: false)
        graph = CharacterSkills::Builder.new(character, data: data, effect_parser: effect_parser).build
        CharacterSkills::JpLocalizer.new(character).apply(graph[:slots])
        report = CharacterSkills::Reporter.new(data: data, status_lookup: status_lookup)
                                          .report_for(graph, unmatched_statuses: effect_parser.unmatched_statuses)
        CharacterSkills::Persister.new(character).persist(graph) if persist
        report
      end

      def self.persist_all(debug: false, overwrite: false)
        characters = Character.where.not(wiki_raw: [nil, ''])
        characters = characters.left_joins(:character_skills).where(character_skills: { id: nil }) unless overwrite

        total = characters.count
        processed = 0
        errors = []
        status_lookup = build_status_lookup

        characters.find_each.with_index do |character, index|
          if debug
            percentage = total.zero? ? 100.0 : ((index + 1) / total.to_f * 100).round(1)
            puts "#{percentage}%: Processing skills for #{character.name_en} (#{character.granblue_id})..."
          end

          new(character, status_lookup: status_lookup).parse(persist: true)
          processed += 1
        rescue StandardError => e
          errors << "#{character.granblue_id}: #{e.message}"
          Rails.logger.error "[CHARACTER_SKILLS] Failed for #{character.granblue_id}: #{e.message}"
        end

        { processed: processed, skipped: total - processed - errors.size, errors: errors }
      end

      # Preloads the Status catalog into name/id indexes for O(1) lookups.
      def self.build_status_lookup
        Status.all.each_with_object({ by_name: {}, by_id: {} }) do |status, acc|
          acc[:by_name][status.name_en.to_s.downcase] = status
          acc[:by_id][status.id] = status
        end
      end

      private

      attr_reader :data

      def status_lookup
        @status_lookup ||= self.class.build_status_lookup
      end

      def effect_parser
        @effect_parser ||= CharacterSkills::EffectParser.new(status_lookup)
      end
    end
  end
end
