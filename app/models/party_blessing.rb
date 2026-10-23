# frozen_string_literal: true

##
# An Arcarum Blessing level equipped on an Evoking Solomonis party.
# arcarum_blessing_id is copied from the level so the unique index can hold a
# party to one level of each blessing.
#
# Write a whole loadout with Party#replace_solomonis_blessings!, which also
# recomputes seal state (Justice) and checks the character limit (The Hanged Man).
class PartyBlessing < ApplicationRecord
  belongs_to :party, inverse_of: :party_blessings
  belongs_to :arcarum_blessing
  belongs_to :arcarum_blessing_level

  before_validation :copy_blessing_from_level

  validates :arcarum_blessing_id, uniqueness: { scope: :party_id }
  validate :level_belongs_to_blessing
  validate :blessing_released
  validate :party_is_solomonis
  validate :within_cost_limit

  delegate :cost, to: :arcarum_blessing_level, allow_nil: true

  def slug
    arcarum_blessing&.slug
  end

  private

  def copy_blessing_from_level
    self.arcarum_blessing ||= arcarum_blessing_level&.arcarum_blessing
  end

  def level_belongs_to_blessing
    return unless arcarum_blessing_level && arcarum_blessing_id
    return if arcarum_blessing_level.arcarum_blessing_id == arcarum_blessing_id

    errors.add(:arcarum_blessing_level, 'must belong to the blessing')
  end

  def blessing_released
    return unless arcarum_blessing
    return if arcarum_blessing.released?

    errors.add(:arcarum_blessing, 'is not released yet')
  end

  def party_is_solomonis
    return unless party
    return if party.solomonis?

    errors.add(:party, 'must be an Evoking Solomonis party')
  end

  def within_cost_limit
    return unless party && arcarum_blessing_level

    others = party.party_blessings.reject do |pb|
      pb.equal?(self) || (id && pb.id == id) || pb.marked_for_destruction?
    end
    total = others.sum { |pb| pb.cost.to_i } + cost.to_i
    return if total <= ArcarumBlessing::COST_LIMIT

    errors.add(:base, "Blessing cost total #{total} exceeds the limit of #{ArcarumBlessing::COST_LIMIT}")
  end
end
