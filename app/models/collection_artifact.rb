# frozen_string_literal: true

class CollectionArtifact < ApplicationRecord
  include ArtifactSkillValidations

  # Associations
  belongs_to :user
  belongs_to :artifact

  has_many :grid_artifacts, dependent: :nullify

  before_destroy :orphan_grid_items

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
  validates :reroll_slot, inclusion: { in: 1..4 }, allow_nil: true

  # Scopes
  scope :by_element, ->(el) { where(element: el) }
  scope :by_artifact, ->(artifact_id) { where(artifact_id: artifact_id) }
  # Filter by proficiency - handles both quirk (instance) and standard (artifact) proficiencies
  scope :by_proficiency, ->(prof) {
    joins(:artifact).where(
      'collection_artifacts.proficiency IN (?) OR (collection_artifacts.proficiency IS NULL AND artifacts.proficiency IN (?))',
      Array(prof), Array(prof)
    )
  }
  scope :by_rarity, ->(rar) { joins(:artifact).where(artifacts: { rarity: rar }) }
  scope :standard_only, -> { joins(:artifact).where(artifacts: { rarity: :standard }) }
  scope :quirk_only, -> { joins(:artifact).where(artifacts: { rarity: :quirk }) }

  # Filter by skill modifier in a specific slot (1-4)
  # Uses OR logic when multiple modifiers are provided
  scope :with_skill_in_slot, ->(slot, modifiers) {
    return all if modifiers.blank?

    modifiers = Array(modifiers).map(&:to_s)
    column = "skill#{slot}"

    # Build OR conditions for multiple modifiers
    conditions = modifiers.map { |_| "#{column}->>'modifier' = ?" }.join(' OR ')
    where(conditions, *modifiers)
  }

  # Returns the effective proficiency - from instance for quirk, from artifact for standard
  def effective_proficiency
    quirk_artifact? ? proficiency : artifact&.proficiency
  end

  private

  def quirk_artifact?
    artifact&.quirk?
  end

  ##
  # Marks all linked grid artifacts as orphaned before destroying this collection artifact.
  #
  # @return [void]
  def orphan_grid_items
    grid_artifacts.update_all(orphaned: true, collection_artifact_id: nil)
  end
end
