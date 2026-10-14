# frozen_string_literal: true

module Api
  module V1
    ##
    # Evoking Solomonis writes nested under a party: the blessing loadout, a
    # run's guidebook and a build's unseal priority. Each replaces the whole
    # list and returns the full party (D11), since blessings change seal state
    # and the character limit.
    #
    # The party is loaded by its id and authorized against its real owner or
    # edit key; every child row is loaded from that party or the catalogue,
    # never trusted from params.
    class PartySolomonisController < Api::V1::ApiController
      include PartyAuthorizationConcern
      include SubstituteGridPreloading
      include PartyFullLoading

      # Upper bounds on list sizes, well above what the game allows.
      MAX_BLESSINGS = ArcarumBlessing::SLUGS.size
      MAX_GUIDE_EFFECTS = 300
      MAX_UNSEAL_ITEMS = 30
      GUIDE_EFFECT_FIELDS = %i[guide_effect_id count display_value acquired_order inherited note].freeze

      # Model validation errors in the usual keyed format.
      rescue_from ActiveRecord::RecordInvalid do |e|
        render_validation_error_response(e.record)
      end

      before_action :set_party
      before_action :authorize_party!

      # PUT /parties/:id/blessings { blessing_level_ids: [uuid, …] }
      def blessings
        ids = list_param(:blessing_level_ids)
        return if performed?
        return render_list_error(:blessings, "can hold at most #{MAX_BLESSINGS} levels") if ids.size > MAX_BLESSINGS

        ids = ids.map(&:to_s)
        levels_by_id = ArcarumBlessingLevel.includes(:arcarum_blessing).where(id: ids).index_by(&:id)
        if ids.uniq.size != ids.size || ids.any? { |id| levels_by_id[id].nil? }
          return render_list_error(:blessings, 'include an unknown or repeated blessing level')
        end

        @party.replace_solomonis_blessings!(ids.map { |id| levels_by_id[id] })
        render_party
      end

      # PUT /parties/:id/guide_effects
      # { guide_effects: [{ guide_effect_id, count, display_value, acquired_order, inherited, note }] }
      def guide_effects
        entries = list_param(:guide_effects)
        return if performed?
        if entries.size > MAX_GUIDE_EFFECTS
          return render_list_error(:guide_effects, "can hold at most #{MAX_GUIDE_EFFECTS} effects")
        end

        return render_list_error(:guide_effects, 'must be objects') unless entries.all?(ActionController::Parameters)
        if entries.any? { |entry| GUIDE_EFFECT_FIELDS.any? { |key| nested?(entry[key]) } }
          return render_list_error(:guide_effects, 'fields must be numbers, text or true/false')
        end

        entries = entries.map { |entry| guide_effect_entry(entry) }

        effects_by_id = SolomonisGuideEffect.where(id: entries.pluck(:guide_effect_id)).index_by(&:id)
        if entries.any? { |entry| effects_by_id[entry[:guide_effect_id]].nil? }
          return render_list_error(:guide_effects, 'include an unknown effect')
        end

        @party.replace_solomonis_guide_effects!(entries.map do |entry|
          entry.except(:guide_effect_id).merge(solomonis_guide_effect: effects_by_id[entry[:guide_effect_id]])
        end)
        render_party
      rescue ActiveRecord::RecordInvalid => e
        raise unless e.record.is_a?(ExpeditionGuideEffect)

        render_list_error(:guide_effects, e.record.errors.full_messages)
      end

      # PUT /parties/:id/unseal_priority { items: [{ type: 'weapon' | 'summon', id }] }
      #
      # One ordered array; weapons and summons are numbered as two separate
      # lists, each from 1 in the order its items appear.
      def unseal_priority
        items = list_param(:items)
        return if performed?
        return render_list_error(:unseal_priority, "can hold at most #{MAX_UNSEAL_ITEMS} items") if items.size > MAX_UNSEAL_ITEMS

        items = items.map do |item|
          next nil unless item.is_a?(ActionController::Parameters)

          { type: item[:type].to_s, id: item[:id].to_s }
        end
        return render_list_error(:unseal_priority, 'items must be objects') if items.any?(&:nil?)

        @party.replace_unseal_priority!(items)
        render_party
      end

      private

      def set_party
        @party = Party.find_by(id: params[:id])
        render_not_found_response('party') unless @party
      end

      # The array at params[key]; an empty array clears the list. Renders a
      # 422 when it's missing or not an array.
      def list_param(key)
        value = params[key]
        return value if value.is_a?(Array)

        render_list_error(key, 'must be a list')
        []
      end

      def nested?(value)
        value.is_a?(Array) || value.is_a?(ActionController::Parameters)
      end

      def guide_effect_entry(entry)
        boolean = ActiveModel::Type::Boolean.new
        {
          guide_effect_id: entry[:guide_effect_id].to_s,
          count: entry[:count].nil? ? 1 : entry[:count],
          display_value: entry[:display_value].presence,
          acquired_order: entry[:acquired_order].presence,
          inherited: boolean.cast(entry[:inherited]) || false,
          note: entry[:note].presence
        }
      end

      def render_list_error(key, messages)
        render json: ErrorBlueprint.render_as_json(nil, errors: { key => Array(messages) }),
               status: :unprocessable_entity
      end

      def render_party
        @party.mark_updated!
        render json: PartyBlueprint.render(load_full_party(@party.id), view: :full, root: :party,
                                                                        current_user: current_user)
      end
    end
  end
end
