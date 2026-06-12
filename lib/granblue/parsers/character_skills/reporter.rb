# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Builds the diagnostic report for a parsed graph: counts, unmatched status
      # names, and cross-validation of parsed statuses against each skill's
      # game-data ailment ids.
      class Reporter
        def initialize(data:, status_lookup:)
          @data = data
          @status_lookup = status_lookup
        end

        def report_for(graph, unmatched_statuses:, missing_fields: [])
          {
            character_granblue_id: graph[:character_granblue_id],
            counts: {
              slots: graph[:slots].size,
              versions: graph[:slots].sum { |slot| slot[:versions].size },
              effects: graph[:slots].sum { |slot| slot[:versions].sum { |version| version[:effects].size } },
              links: graph[:links].size
            },
            unmatched_statuses: unmatched_statuses.to_a.sort,
            missing_fields: missing_fields.uniq,
            cross_validation: cross_validate_statuses(graph),
            slots: graph[:slots],
            links: graph[:links]
          }
        end

        private

        attr_reader :data, :status_lookup

        def cross_validate_statuses(graph)
          graph[:slots].flat_map do |slot|
            slot[:versions].filter_map do |version|
              game_ids = data.csv(data.game_action(version[:source_key])&.dig('ailment'))
              parsed_ids = version[:effects].filter_map { |effect| effect[:status_id] && status_ailment_id(effect[:status_id]) }
              missing = game_ids - parsed_ids
              next if missing.empty?

              {
                slot: slot[:attrs].slice(:kind, :position),
                version: version[:attrs][:name_en],
                missing_game_ailment_ids: missing
              }
            end
          end
        end

        def status_ailment_id(status_id)
          status_lookup[:by_id][status_id]&.game_ailment_id
        end
      end
    end
  end
end
