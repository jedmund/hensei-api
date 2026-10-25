# frozen_string_literal: true

class Artifact < ApplicationRecord
  enum :proficiency, GranblueEnums::PROFICIENCY_ENUM

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
