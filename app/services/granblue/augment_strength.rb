# frozen_string_literal: true

module Granblue
  # Parses the strength of an augment skill (AX or befoulment) from the game's
  # `effect_value` / `show_value` pair. Shared by party import and collection import.
  module AugmentStrength
    module_function

    # @param effect_value [String, Numeric, nil] e.g. "3", "1_3"
    # @param show_value [String, nil] e.g. "3%", "+3"
    # @return [Float, nil]
    def parse(effect_value, show_value)
      if effect_value.present?
        # Handle "1_3" format (seems to be "tier_value")
        return effect_value.to_s.split('_').last.to_f if effect_value.to_s.include?('_')
        return effect_value.to_f if effect_value.to_s.match?(/\A[\d.]+\z/)
      end

      # Try show_value (e.g., "3%")
      return show_value.to_s.gsub('%', '').to_f if show_value.present?

      nil
    end
  end
end
