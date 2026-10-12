# frozen_string_literal: true

module Api
  module V1
    # The `solomonis` object on a party.
    #
    # - :full (party page): route Evoker, zone, the expedition fields, the
    #   blessing loadout and, for runs, the guidebook. Pass `current_user` so a
    #   linked build the viewer can't see renders as null.
    # - :summary (party cards and search): kind, route Evoker id, pledge level.
    #
    # Reads the party's preloaded associations (see PartyFullLoading).
    class SolomonisExpeditionBlueprint < Blueprinter::Base
      # Effects held at the end of a run, in the game's order: by pickup when
      # known, then unique, rare, normal, cursed.
      RARITY_ORDER = %w[unique rare normal cursed].freeze

      view :summary do
        fields :kind, :route_evoker_id, :pledge_level
      end

      view :full do
        fields :kind, :pledge_level, :outcome, :bosses_defeated, :midboss, :expedition_level,
               :game_report_id, :ended_at, :stats

        association :route_evoker, blueprint: SolomonisRouteEvokerBlueprint

        field :zone do |expedition|
          SolomonisRouteEvokerBlueprint.zone_hash(expedition.party.raid)
        end

        field :build_party do |expedition, options|
          build = expedition.build_party
          next nil unless build&.viewable_by?(options[:current_user])

          { shortcode: build.shortcode, name: build.name }
        end

        field :blessing_cost_limit do
          ArcarumBlessing::COST_LIMIT
        end

        field :blessing_cost_total do |expedition|
          expedition.party.solomonis_blessing_cost_total
        end

        field :blessings do |expedition|
          expedition.party.party_blessings
                    .sort_by { |pb| pb.arcarum_blessing.arcana_number }
                    .map do |pb|
            {
              blessing: ArcarumBlessingBlueprint.render_as_hash(pb.arcarum_blessing),
              level_id: pb.arcarum_blessing_level_id,
              level: pb.arcarum_blessing_level.level,
              cost: pb.arcarum_blessing_level.cost
            }
          end
        end

        field :guidebook do |expedition|
          next [] unless expedition.run?

          SolomonisExpeditionBlueprint.sorted_guidebook(expedition.party.expedition_guide_effects).map do |entry|
            {
              effect: SolomonisGuideEffectBlueprint.render_as_hash(entry.solomonis_guide_effect),
              count: entry.count,
              display_value: entry.display_value,
              acquired_order: entry.acquired_order,
              inherited: entry.inherited,
              note: entry.note
            }
          end
        end
      end

      def self.sorted_guidebook(entries)
        entries.sort_by do |entry|
          effect = entry.solomonis_guide_effect
          [entry.acquired_order || Float::INFINITY, RARITY_ORDER.index(effect.rarity) || RARITY_ORDER.size,
           effect.granblue_id]
        end
      end
    end
  end
end
