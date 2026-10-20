# frozen_string_literal: true

module Granblue
  module Parsers
    # Public façade for parsing a character's wiki/game data into the normalized
    # skill graph. Orchestrates the CharacterSkills::* collaborators: Builder
    # assembles the graph and JpLocalizer fills Japanese text (#graph, pure: it reads
    # the record and the statuses catalogue, never the network or skill rows), and
    # Reporter builds the diagnostic report (#report). Writing is
    # CharacterSkills::Build's job (::CharacterSkills::Build::Runner and Writer).
    class CharacterSkillParser
      attr_reader :character

      # status_lookup: an optional preloaded { by_name:, by_id: } index so a batch
      # run resolves the Status catalog once instead of per character.
      def initialize(character, status_lookup: nil)
        @character = character
        @data = CharacterWikiData.new(character)
        @status_lookup = status_lookup
      end

      # → { character_granblue_id:, slots:, links: }, built once per parser.
      def graph
        @graph ||= CharacterSkills::Builder.new(character, data: data, effect_parser: effect_parser).build.tap do |built|
          CharacterSkills::JpLocalizer.new(character).apply(built[:slots])
        end
      end

      def report
        CharacterSkills::Reporter.new(data: data, status_lookup: status_lookup)
                                 .report_for(graph, unmatched_statuses: effect_parser.unmatched_statuses)
      end

      # The report; persist: true also builds and writes this character's skills through
      # the build runner (write mode, even when not stale). Kept for the report tasks
      # and callers that still pass persist:.
      def parse(persist: false)
        if persist
          summary = ::CharacterSkills::Build::Runner.new(mode: 'write', characters: [character], all: true,
                                                         io: StringIO.new).call
          raise summary.errors.first.last if summary.errors.any?
        end
        report
      end

      # Preloads the Status catalog into name/id indexes for O(1) lookups. Several statuses
      # can share a name (one per game ailment id); the oldest wins, so a name resolves the
      # same way on every build, and a status added later doesn't move existing effects.
      def self.build_status_lookup
        Status.order(:created_at, :id).each_with_object({ by_name: {}, by_id: {} }) do |status, acc|
          acc[:by_name][status.name_en.to_s.downcase] ||= status
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
