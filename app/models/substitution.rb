# frozen_string_literal: true

class Substitution < ApplicationRecord
  belongs_to :grid, polymorphic: true
  belongs_to :substitute_grid, polymorphic: true

  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10 }

  validate :grid_types_must_match
  validate :no_self_substitution

  private

  def grid_types_must_match
    return if grid_type.blank? || substitute_grid_type.blank?

    unless grid_type == substitute_grid_type
      errors.add(:substitute_grid_type, 'must match grid type')
    end
  end

  def no_self_substitution
    return if grid_id.blank? || substitute_grid_id.blank?

    if grid_type == substitute_grid_type && grid_id == substitute_grid_id
      errors.add(:substitute_grid, 'cannot reference itself')
    end
  end
end
