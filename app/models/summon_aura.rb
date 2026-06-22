# frozen_string_literal: true

# A summon's passive aura (main or sub) at a given uncap/transcendence tier, parsed from
# the wiki. Populated by `rake granblue:load_summon_aura_data`; consumed by the grid
# damage calculator (frame multipliers + the Elemental boost).
class SummonAura < ApplicationRecord
  SLOTS = %w[main sub].freeze
  # How the aura enters the damage formula:
  #   normal_frame / omega_frame — multiplies the weapon mods in that frame (Optimus/Magna)
  #   elemental_atk              — additive to the Elemental boost category
  #   normal_atk / omega_atk     — additive within the frame (e.g. Grand Order)
  #   multiattack                — DA/TA up (not an ATK frame)
  #   other                      — charge bar / call / cap / etc. (not modeled in the MVP)
  TARGETS = %w[normal_frame omega_frame elemental_atk normal_atk omega_atk atk multiattack other].freeze

  belongs_to :summon, foreign_key: :summon_granblue_id, primary_key: :granblue_id,
                      inverse_of: :auras, optional: true

  validates :summon_granblue_id, presence: true
  validates :slot, inclusion: { in: SLOTS }
  validates :target, inclusion: { in: TARGETS }

  scope :main, -> { where(slot: "main") }
  scope :sub, -> { where(slot: "sub") }
end
