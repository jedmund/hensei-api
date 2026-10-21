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

      # Ties between same-name categories go to the first of these; a field row also beats a
      # buff majority (field states such as Sun-touched Paradise get mislabelled as buffs).
      CATEGORY_TIE_ORDER = %w[field buff debuff special].freeze

      # Preloads the Status catalog into name/id indexes for O(1) lookups.
      #
      # Several statuses can share a name (one per game ailment id, often paired with the
      # name by mistake, so their categories disagree). A name resolves to the majority
      # category among its rows (ties: field, then buff; a field row beats buff), then the
      # oldest row in that category. Deterministic, and right for 97% of the hand-labelled
      # effects in the 2026-10 status audit, where "oldest row" was right for 44%.
      def self.build_status_lookup
        statuses = Status.order(:created_at, :id).to_a
        by_name = statuses.group_by { |status| status.name_en.to_s.downcase }
                          .transform_values { |rows| resolve_same_name(rows) }
        { by_name: by_name, by_id: statuses.index_by(&:id) }
      end

      # rows: same-name statuses, oldest first.
      def self.resolve_same_name(rows)
        return rows.first if rows.size == 1

        counts = rows.filter_map(&:category).tally
        return rows.first if counts.empty?

        top = counts.values.max
        tied = counts.select { |_, count| count == top }.keys
        category = CATEGORY_TIE_ORDER.find { |c| tied.include?(c) } || tied.min
        category = 'field' if category == 'buff' && counts.key?('field')
        rows.find { |row| row.category == category }
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
