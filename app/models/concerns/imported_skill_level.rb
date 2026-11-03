# frozen_string_literal: true

# A weapon copy's skill level comes from the game import and describes the copy as it
# was then; the web app never shows or edits it. An edit that changes the uncap, or
# moves transcendence to or from stage 5 (SL25), without sending a level would keep
# that old level (a 3★ import's SL10 on a copy raised to 4★), so it's dropped and the
# calculator assumes the new cap (GridDamage::WeaponContributions.skill_level_for).
module ImportedSkillLevel
  extend ActiveSupport::Concern

  # Assigns attrs and drops the saved level when they change the uncap without one.
  def assign_with_skill_level(attrs)
    assign_attributes(attrs)
    return if attrs.to_h.stringify_keys.key?('skill_level')
    return unless will_save_change_to_uncap_level? || final_transcendence_changed?

    self.skill_level = nil
  end

  # Only Transcendence 5 raises the cap (SL20 → SL25); stages 1–4 leave it, so they
  # keep an imported level.
  def final_transcendence_changed?
    return false unless will_save_change_to_transcendence_step?

    before, after = transcendence_step_change_to_be_saved.map { |step| step.to_i >= 5 }
    before != after
  end
end
