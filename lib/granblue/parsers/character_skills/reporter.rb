# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Builds the diagnostic report for a parsed graph: counts and unmatched
      # status names.
      class Reporter
        def report_for(graph, unmatched_statuses:, counted_instants: [], missing_fields: [])
          {
            character_granblue_id: graph[:character_granblue_id],
            counts: {
              slots: graph[:slots].size,
              versions: graph[:slots].sum { |slot| slot[:versions].size },
              effects: graph[:slots].sum { |slot| slot[:versions].sum { |version| version[:effects].size } },
              links: graph[:links].size
            },
            unmatched_statuses: unmatched_statuses.to_a.sort,
            counted_instants: counted_instants,
            missing_fields: missing_fields.uniq,
            slots: graph[:slots],
            links: graph[:links]
          }
        end
      end
    end
  end
end
