# frozen_string_literal: true

# A weapon copy's skill level comes from the game import and describes the copy as it
# was then; the web app never shows or edits it. An edit that changes the uncap or
# transcendence without sending a level would keep that old level (a 3★ import's SL10
# on a copy raised to 4★), so it's dropped and the calculator assumes the new uncap's
# cap (GridDamage::WeaponContributions.skill_level_for).
module ImportedSkillLevel
  extend ActiveSupport::Concern

  # Assigns attrs and drops the saved level when they change the uncap without one.
  def assign_with_skill_level(attrs)
    assign_attributes(attrs)
    return if attrs.to_h.stringify_keys.key?('skill_level')
    return unless will_save_change_to_uncap_level? || will_save_change_to_transcendence_step?

    self.skill_level = nil
  end
end
