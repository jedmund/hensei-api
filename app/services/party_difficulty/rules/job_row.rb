# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when the party's job belongs to the specified row, optionally
    # requiring the party's job ultimate mastery level to be set.
    #
    # params: { "rows": ["IV", "V", "Origin"], "requires_ultimate_mastery": false }
    class JobRow < Base
      def self.component
        'job'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:rows].present? ? [] : ['rows must be provided']
      end

      def applies?(party)
        return false unless party.job

        rows = string_array_param(:rows)
        return false unless rows.include?(party.job.row.to_s)

        params[:requires_ultimate_mastery] == true ? party.ultimate_mastery_level.to_i.positive? : true
      end

      def matching_count(party)
        applies?(party) ? 1 : 0
      end
    end
  end
end
