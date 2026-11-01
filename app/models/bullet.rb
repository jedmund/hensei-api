# frozen_string_literal: true

class Bullet < ApplicationRecord
  include GranblueEnums
  include Slugged

  # Five digits: the type, a two-digit family and a two-digit step (10101 is
  # Iron Bullet, a Parabellum). Every bullet has one, and the editor and old
  # links address bullets by it.
  GRANBLUE_ID_FORMAT = /\A\d{5}\z/

  # A bullet loaded on a party's or a collection's weapon can't be deleted
  has_many :grid_weapon_bullets, dependent: :restrict_with_error
  has_many :collection_weapon_bullets, dependent: :restrict_with_error

  validates :granblue_id, presence: true, format: { with: GRANBLUE_ID_FORMAT }, uniqueness: true
  validates :name_en, presence: true
  validates :bullet_type, presence: true, inclusion: { in: BULLET_TYPES.values }
  validates :atk, :order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :by_type, ->(type) { where(bullet_type: type) }

  def blueprint
    Api::V1::BulletBlueprint
  end
end
