# frozen_string_literal: true

# The family registry — one row per {{Weapon Skills/<name>}} wiki template.
# aura_boostable is the family-level amplifiability bit (WsBox header);
# boosts lists the panel boost labels the family grants (boost1..N).
class WeaponSkillFamily < ApplicationRecord
  validates :name, presence: true, uniqueness: true
end
