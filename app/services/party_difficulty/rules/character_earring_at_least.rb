# frozen_string_literal: true

module PartyDifficulty
  module Rules
    ##
    # Fires when at least min_count grid characters have an earring with
    # strength >= min_strength.
    #
    # params: { "min_strength": 17, "min_count": 1 }
    class CharacterEarringAtLeast < Base
      def self.component
        'character'
      end

      def self.validate_params(params)
        params = (params || {}).with_indifferent_access
        params[:min_strength].to_i.positive? ? [] : ['min_strength must be > 0']
      end

      def matching_count(party)
        min_strength = params[:min_strength].to_f

        party.characters.count do |gc|
          earring = gc.earring.is_a?(Hash) ? gc.earring.with_indifferent_access : {}
          modifier = earring[:modifier]
          strength = earring[:strength]
          next false if modifier.blank? || strength.blank?

          strength.to_f >= min_strength
        end
      end
    end
  end
end
