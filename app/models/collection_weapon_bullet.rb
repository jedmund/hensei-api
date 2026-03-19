# frozen_string_literal: true

class CollectionWeaponBullet < ApplicationRecord
  belongs_to :collection_weapon
  belongs_to :bullet

  validates :position, presence: true
  validates :position, uniqueness: { scope: :collection_weapon_id }

  validate :position_within_bounds
  validate :bullet_type_matches_slot

  private

  def position_within_bounds
    return unless collection_weapon&.weapon&.bullet_slots.present?

    max_position = collection_weapon.weapon.bullet_slots.length - 1
    unless position.present? && position >= 0 && position <= max_position
      errors.add(:position, "must be between 0 and #{max_position}")
    end
  end

  def bullet_type_matches_slot
    return unless collection_weapon&.weapon&.bullet_slots.present? && bullet.present? && position.present?

    expected_type = collection_weapon.weapon.bullet_slots[position]
    unless bullet.bullet_type == expected_type
      errors.add(:bullet, "type must match the slot type at position #{position}")
    end
  end
end
