# frozen_string_literal: true

module GridDamage
  # The battle state (the game's "Calculator Conditions") the skill boost panel
  # is computed for, sanitized from request params: HP and turn clamped, max HP
  # for max-HP-scaled effects, Arcarum for venue-gated effects, and the foe
  # element whitelisted, defaulting to what the grid element is strong against
  # like the in-game estimate.
  module PanelState
    module_function

    ##
    # @param params [ActionController::Parameters, Hash] hp_percent (0-100),
    #   turn (1+), ally_max_hp, arcarum and foe_element
    # @param party [Party] whose grid element sets the default foe
    # @return [Hash] the state, without the keys left unset
    def from_params(params, party)
      {
        hp_percent: params[:hp_percent].presence&.to_f&.clamp(0, 100) || 100.0,
        ally_max_hp: params[:ally_max_hp].presence&.to_f&.clamp(0, 999_999),
        turn: params[:turn].presence&.to_i&.clamp(1, 999) || 1,
        foe_element: foe_element(params[:foe_element], party),
        arcarum: ActiveModel::Type::Boolean.new.cast(params[:arcarum]) || false
      }.compact
    end

    # "null" is a real foe element (element-less foes): advantaged effects turn off.
    def foe_element(requested, party)
      foe = requested.presence&.downcase
      return foe if foe == 'null' || Calculator::ELEMENT_WORD.value?(foe)

      Calculator::ADVANTAGED_FOE[ElementScope.panel_element(party)]
    end
  end
end
