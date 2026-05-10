# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count summons have transcendence_step >= min_step.
    #
    # params: { "min_step": 4, "min_count": 1 }
    class SummonTranscendenceAtLeast < Base
      def self.component
        'summon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:min_step].to_i.positive? ? [] : ['min_step must be > 0']
      end

      def matching_count(party)
        min_step = params[:min_step].to_i
        party.summons.count { |gs| gs.transcendence_step.to_i >= min_step }
      end
    end
  end
end
