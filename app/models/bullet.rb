# frozen_string_literal: true

class Bullet < ApplicationRecord
  include GranblueEnums

  validates :name_en, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :granblue_id, uniqueness: true, allow_nil: true
  validates :bullet_type, presence: true, inclusion: { in: BULLET_TYPES.values }

  scope :by_type, ->(type) { where(bullet_type: type) }

  def blueprint
    Api::V1::BulletBlueprint
  end
end
