# frozen_string_literal: true

##
# A guidebook effect held at the end of an Evoking Solomonis run, with its
# stack count. Write a run's whole guidebook with
# Party#replace_solomonis_guide_effects!.
class ExpeditionGuideEffect < ApplicationRecord
  DISPLAY_VALUE_MAX_LENGTH = 64
  NOTE_MAX_LENGTH = 200
  # Well above anything a run reaches, and inside the int4 columns.
  MAX_COUNT = 999
  MAX_ACQUIRED_ORDER = 999

  belongs_to :party, inverse_of: :expedition_guide_effects
  belongs_to :solomonis_guide_effect

  validates :solomonis_guide_effect_id, uniqueness: { scope: :party_id }
  validates :count, numericality: { only_integer: true, in: 1..MAX_COUNT }
  validates :acquired_order, numericality: { only_integer: true, in: 1..MAX_ACQUIRED_ORDER }, allow_nil: true
  validates :display_value, length: { maximum: DISPLAY_VALUE_MAX_LENGTH }, allow_nil: true
  validates :note, length: { maximum: NOTE_MAX_LENGTH }, allow_nil: true
  validates :inherited, inclusion: { in: [true, false] }
  validates :inherited, uniqueness: { scope: :party_id, message: 'can only be set on one effect per party' },
                        if: :inherited?
  validate :count_one_unless_stackable
  validate :party_is_solomonis

  private

  def count_one_unless_stackable
    return unless solomonis_guide_effect && count.to_i > 1
    return if solomonis_guide_effect.stackable?

    errors.add(:count, 'must be 1 for an effect that cannot be stacked')
  end

  def party_is_solomonis
    return unless party
    return if party.solomonis?

    errors.add(:party, 'must be an Evoking Solomonis party')
  end
end
