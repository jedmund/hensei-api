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
    end
  end
end
