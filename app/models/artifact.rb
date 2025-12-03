# frozen_string_literal: true

class Artifact < ApplicationRecord
  # Enums - using GranblueEnums::PROFICIENCY values (excluding None: 0)
  # Sabre: 1, Dagger: 2, Axe: 3, Spear: 4, Bow: 5, Staff: 6, Melee: 7, Harp: 8, Gun: 9, Katana: 10
  enum :proficiency, {
    sabre: 1,
    dagger: 2,
    axe: 3,
    spear: 4,
    bow: 5,
    staff: 6,
    melee: 7,
    harp: 8,
    gun: 9,
    katana: 10
  }

  enum :rarity, { standard: 0, quirk: 1 }

  # Associations
  has_many :collection_artifacts, dependent: :restrict_with_error
  has_many :grid_artifacts, dependent: :restrict_with_error

  # Validations
  validates :granblue_id, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :proficiency, presence: true, if: :standard?
  validates :proficiency, absence: true, if: :quirk?
  validates :rarity, presence: true

  # Scopes
  scope :standard_artifacts, -> { where(rarity: :standard) }
  scope :quirk_artifacts, -> { where(rarity: :quirk) }
  scope :by_proficiency, ->(prof) { where(proficiency: prof) }
end
