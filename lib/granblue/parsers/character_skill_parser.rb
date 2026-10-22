# frozen_string_literal: true

module Granblue
  module Parsers
    # Public façade for parsing a character's wiki/game data into the normalized
    # skill graph. Orchestrates the CharacterSkills::* collaborators: Builder
    # assembles the graph, JpLocalizer fills Japanese text and JpSkillText applies curated
    # Japanese text over the wiki's (#graph, pure: it reads
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
          game_fields = CharacterSkills::JpSkillText.game_fields(built[:slots])
          CharacterSkills::JpLocalizer.new(character).apply(built[:slots])
          CharacterSkills::JpSkillText.new(character).apply(built[:slots], game_fields: game_fields)
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

      # Preloads the Status catalog into name/id indexes for O(1) lookups. Names are unique
      # (statuses.name_key), so a name resolves to its one status.
      def self.build_status_lookup
        statuses = Status.order(:created_at, :id).to_a
        { by_name: statuses.index_by { |status| status.name_key || Status.normalize_name(status.name_en) },
          by_id: statuses.index_by(&:id) }
      end

      private

      attr_reader :data

      def status_lookup
        @status_lookup ||= self.class.build_status_lookup
      end

      def effect_parser
        @effect_parser ||= CharacterSkills::EffectParser.new(status_lookup, granblue_id: character.granblue_id)
      end
    end
  end
end
