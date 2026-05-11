# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Base class for all difficulty rules. Rules answer one question:
    # given a party, does this rule fire? If so, the party gets the rule's
    # weight added to the relevant component sub-score.
    #
    # Most rules implement a count-based pattern: they iterate over the
    # relevant grid items and return how many match. The rule fires when
    # `matching_count >= min_count`.
    class Base
      def initialize(params = {})
        @params = (params || {}).with_indifferent_access
      end

      attr_reader :params

      def applies?(party)
        matching_count(party) >= min_count
      end

      ##
      # Subclasses must declare which component they belong to:
      # 'weapon', 'character', 'summon', 'job', or 'accessory'.
      def self.component
        raise NotImplementedError
      end

      ##
      # Return an array of error message strings if params are invalid;
      # empty array if valid.
      def self.validate_params(_params)
        []
      end

      def matching_count(_party)
        raise NotImplementedError
      end

      ##
      # Per-match contribution multipliers, one per matched item. Default is
      # 1.0 for every match. Rules that want age-decay or other per-item
      # scaling (e.g. weapon_seasonal_match) override this. The calculator
      # multiplies these factors by the rule's weight and sums up to `max_count`
      # of them to compute the contribution.
      def match_factors(party)
        Array.new(matching_count(party), 1.0)
      end

      def min_count
        value = params[:min_count].to_i
        value.positive? ? value : 1
      end

      protected

      def integer_array_param(key)
        Array(params[key]).map { |v| v.to_s.match?(/\A\d+\z/) ? v.to_i : v.to_s }
      end

      def string_array_param(key)
        Array(params[key]).map(&:to_s)
      end

      ##
      # Resolve a list of series slugs to ids, honoring a thread-local cache when
      # complete and falling back to the DB on any miss. A partial cache hit
      # would silently drop unrecognized slugs, so we require every slug to be
      # present before trusting the cache.
      def resolve_slugs_via_cache(slugs, cache, model)
        return [] if slugs.empty?
        return slugs.filter_map { |s| cache[s] } if cache && slugs.all? { |s| cache.key?(s) }

        model.where(slug: slugs).pluck(:id)
      end

      ##
      # Returns a decay multiplier in [floor, 1.0] for an item released
      # `years_since(release_date)` years ago. Reads `decay_per_year` and
      # `decay_floor` from the rule's params (defaults: 0 = no decay, floor 0.1).
      def decay_factor_for(release_date)
        rate = params[:decay_per_year].to_f
        return 1.0 if rate <= 0 || release_date.nil?

        years = (Date.current - release_date).to_f / 365.25
        floor = params[:decay_floor].present? ? params[:decay_floor].to_f : 0.1
        [1.0 - (rate * years), floor].max
      end
    end
  end
end
