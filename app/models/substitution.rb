# frozen_string_literal: true

class Substitution < ApplicationRecord
  GRID_TYPES = %w[GridCharacter GridWeapon GridSummon].freeze
  MAX_PER_GRID_ITEM = 10

  belongs_to :grid, polymorphic: true
  belongs_to :substitute_grid, polymorphic: true

  validates :position, presence: true,
                       numericality: { only_integer: true,
                                       greater_than_or_equal_to: 0,
                                       less_than: MAX_PER_GRID_ITEM }
  validates :grid_type, inclusion: { in: GRID_TYPES }

  validate :types_must_match
  validate :substitution_limit

  private

  def types_must_match
    return if grid_type == substitute_grid_type

    errors.add(:substitute_grid_type, 'must match grid_type')
  end

  def substitution_limit
    return unless grid_id.present? && grid_type.present?

    count = Substitution.where(grid_type: grid_type, grid_id: grid_id).count
    count -= 1 if persisted? # don't count self on update
    return unless count >= MAX_PER_GRID_ITEM

    errors.add(:base, "cannot have more than #{MAX_PER_GRID_ITEM} substitutions per grid item")
  end
end
