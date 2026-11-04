# frozen_string_literal: true

##
# Uncap ceilings for catalog items that uncap by their flags (weapons and
# summons): 3★ base, 4★ with FLB, 5★ with ULB, and 6 with transcendence,
# which also opens transcendence steps 1-5. Characters have their own rules
# (Character#max_uncap_level).
module UncapTiers
  extend ActiveSupport::Concern

  MAX_TRANSCENDENCE_STEP = 5

  # @return [Integer] the highest uncap level the item reaches
  def max_uncap_level
    if transcendence
      6
    elsif ulb
      5
    elsif flb
      4
    else
      3
    end
  end

  # @return [Integer] the highest transcendence step the item reaches
  def max_transcendence_step
    transcendence ? MAX_TRANSCENDENCE_STEP : 0
  end
end
