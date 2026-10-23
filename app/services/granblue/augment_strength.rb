# frozen_string_literal: true

module Granblue
  # Parses the strength of an augment skill (AX or befoulment) from the game's
  # `effect_value` / `show_value` pair. Shared by party import and collection import.
  module AugmentStrength
    module_function

    # @param effect_value [String, Numeric, nil] e.g. "3", "2_5"
    # @param show_value [String, nil] e.g. "3%", "+3"
    # @return [Float, nil]
    def parse(effect_value, show_value)
      if effect_value.present?
        # Some secondaries (e.g. Stamina, Enmity) send a tier-prefixed value like
        # "2_5" whose segments don't map directly to the displayed strength
        # ("+3"). show_value is what the player sees, so trust it here.
        return show_value_number(show_value) || effect_value.to_s.split('_').last.to_f if effect_value.to_s.include?('_')
        return effect_value.to_f if effect_value.to_s.match?(/\A[\d.]+\z/)
      end

      show_value_number(show_value)
    end

    # @param show_value [String, nil] e.g. "+3%"
    # @return [Float, nil]
    def show_value_number(show_value)
      number = show_value.to_s[/[-+]?\d+(?:\.\d+)?/]
      number&.to_f
    end
  end
end
