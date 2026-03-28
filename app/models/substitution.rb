# frozen_string_literal: true

class Substitution < ApplicationRecord
  belongs_to :grid, polymorphic: true
  belongs_to :substitute_grid, polymorphic: true

  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10 }

  validate :grid_types_must_match
  validate :substitution_cap

  private

  def grid_types_must_match
    return if grid_type.blank? || substitute_grid_type.blank?

    unless grid_type == substitute_grid_type
      errors.add(:substitute_grid_type, 'must match grid type')
    end
  end

  def substitution_cap
    return unless grid.present?

    existing = Substitution.where(grid_type: grid_type, grid_id: grid_id)
    existing = existing.where.not(id: id) if persisted?

    if existing.count >= 10
      errors.add(:base, 'maximum of 10 substitutions per slot')
    end
  end
end
