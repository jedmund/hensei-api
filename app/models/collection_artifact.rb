# frozen_string_literal: true

class CollectionArtifact < ApplicationRecord
  include ArtifactSkillValidations

  # Associations
  belongs_to :user
  belongs_to :artifact

  # Enums - using GranblueEnums::ELEMENTS values (excluding Null)
  # Wind: 1, Fire: 2, Water: 3, Earth: 4, Dark: 5, Light: 6
  enum :element, {
    wind: 1,
    fire: 2,
    water: 3,
    earth: 4,
    dark: 5,
    light: 6
  }

  # Proficiency enum - only used for quirk artifacts (game assigns random proficiency)
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

  # Validations
  validates :element, presence: true
  validates :level, presence: true, inclusion: { in: 1..5 }
  validates :nickname, length: { maximum: 50 }, allow_blank: true
  validates :proficiency, presence: true, if: :quirk_artifact?
  validates :proficiency, absence: true, unless: :quirk_artifact?

  # Scopes
  scope :by_element, ->(el) { where(element: el) }
  scope :by_artifact, ->(artifact_id) { where(artifact_id: artifact_id) }
  scope :by_proficiency, ->(prof) { where(proficiency: prof) }
  scope :by_rarity, ->(rar) { joins(:artifact).where(artifacts: { rarity: rar }) }
  scope :standard_only, -> { joins(:artifact).where(artifacts: { rarity: :standard }) }
  scope :quirk_only, -> { joins(:artifact).where(artifacts: { rarity: :quirk }) }

  # Returns the effective proficiency - from instance for quirk, from artifact for standard
  def effective_proficiency
    quirk_artifact? ? proficiency : artifact&.proficiency
  end

  private

  def quirk_artifact?
    artifact&.quirk?
  end
end
