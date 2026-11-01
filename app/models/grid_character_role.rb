# frozen_string_literal: true

class GridCharacterRole < ApplicationRecord
  has_many :grid_character_role_assignments, dependent: :destroy, inverse_of: :grid_character_role
  has_many :grid_characters, through: :grid_character_role_assignments

  # Written only by the icon upload, at a stable per-role path
  ICON_KEY_FORMAT = %r{\Aimages/grid_character_roles/[0-9a-f-]+\.png\z}

  validates :name_en, presence: true
  # The controller fills a missing sort_order with the next free one on create
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :icon_key, format: { with: ICON_KEY_FORMAT }, allow_nil: true

  # The icon's path with a version query, so a re-upload changes the public
  # URL (the S3 object stays at the plain path; the CDN keys on the query)
  def versioned_icon_key
    "#{icon_key}?v=#{updated_at.to_i}" if icon_key.present?
  end
end
