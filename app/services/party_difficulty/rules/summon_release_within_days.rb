# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count summons (excluding friend summons) were
    # released between `min_days_ago` (inclusive, default 0) and `days`
    # (exclusive) days ago. Mirrors the weapon and character variants.
    #
    # params: { "days": 14, "min_days_ago": 0, "min_count": 1 }
    class SummonReleaseWithinDays < Base
      def self.component
        'summon'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:days].to_i.positive? ? [] : ['days must be > 0']
      end

      def matching_count(party)
        upper = params[:days].to_i.days.ago.to_date
        lower_days = params[:min_days_ago].to_i
        lower = lower_days.positive? ? lower_days.days.ago.to_date : Date.current

        party.summons
             .reject { |gs| gs.friend == true }
             .count do |gs|
          release = gs.summon&.release_date
          release && release >= upper && release <= lower
        end
      end
    end
  end
end
